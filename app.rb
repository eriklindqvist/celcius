require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'mongoid'
require 'json'
require 'tilt/erubis'
require 'open-uri'
require 'nokogiri'

require_relative 'helpers/init'

Mongoid.load!("mongoid.yml")
Mongo::Logger.logger.level = Logger::INFO

class Celcius < Sinatra::Base
  enable :logging

  set :curve, 3  # Sätt till kurvlutningen inställd på reglercentralen
  set :offset, 0 # Sätt till kurvförskjutningen inställd på reglercentralen
  set :prognose_url, "http://www.yr.no/sted/Sverige/Kronoberg/Brittatorp/varsel_time_for_time.xml"

  CURVES = [-0.4583333333333333, -0.625, -0.7708333333333334, -0.9583333333333334, -1.3333333333333333, -2.0, -2.4827586206896552, -3.130434782608696]
  OFFSETS = [28, 32, 36, 40, 45, 53, 61, 73]

  get '/fire' do
    content_type :json

    temperature = Sensor.where(name: "Utomhus").first.current_value

    # Beräkna tillgänglig värme i toppen av tanken
    available = get_available_heat(1.day.ago, 1.day.from_now).values.last

    # Beräkna önskad framledningstemperatur just nu
    desired = get_desired_heat(settings.curve, settings.offset, temperature)

    if desired >= available
      message = "Ja"
    else
      doc = Nokogiri::XML(open("http://www.yr.no/sted/Sverige/Kronoberg/Brittatorp/varsel_time_for_time.xml"))
      future = doc.xpath('//temperature/@value')[0..23].map(&:text).map(&:to_i)
        .find_index{|i| get_desired_heat(settings.curve, settings.offset, i) >= available }

      message = future ? "Om #{future} timmar" : "Nej"
    end

    {
      outside_temp: temperature,
      available_heat: available,
      desired_heat: desired,
      need_fire: message
    }.to_json
  end

  get '/forecast' do
    @data = get_forecast.to_json
    erb :forecast
  end

  get '/data' do
    content_type :json
    get_todays_metrics.to_json
  end

  # curl http://localhost:4004/el
  get '/energy' do
    erb :energy
  end

  # curl http://localhost:4004/energy/daily/2016-03-31
  get '/energy/daily/?:date?' do
    content_type :json
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    get_energies(date-1, date+1).first.to_json
  end

  # curl http://localhost:4004/energy/monthly
  get '/energy/monthly/?:date?' do
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    first = Date.new(date.year, date.month, 1) - 1
    date2 = date + 1.month
    last = Date.new(date2.year, date2.month, 1)
    energies = get_all_energies(first, last)
    sum = energies["Elm\u00E4tare"].map(&:last).inject(&:+)
    avg = energies["Elm\u00E4tare"][0..-2].map(&:last).inject(&:+).to_f/(energies.length-1)
    forecast = avg * date.end_of_month.day
    @data = { energies: energies,
      summary: {sum: sum, avg: avg, forecast: forecast}
    }.to_json
    erb :monthly
  end

  get '/energy/yearly/?:date?' do
    content_type :json
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    first = Date.new(date.year-1, 12, 31)
    last = Date.new(date.year+1, 1, 1)
    energies = get_energies(first, last)
    energies.group_by{|e| e.first.month }.map{|m| [m.first, m.last.map(&:last).inject(&:+)] }.to_h.to_json
  end

  # curl -X POST -d "sensor=1&value=123.235&time=12345" http://localhost:4004/temperature
  post '/temperature' do
    begin
      sensor = Sensor.find_by uid: param(:sensor)
      value = Float(param(:value))
    rescue => e
      halt 400, e.message
    end

    time = Time.at((params[:time] || Time.now).to_i)
    logger.info "sensor: #{sensor}, value: #{value}, time: #{time}"
    Value.create(sensor, time, value)
  end

  # curl -X POST -d "sensor=1&value=12345&time=12345" http://localhost:4004/pulses
  post '/pulses' do
    begin
      sensor = EnergySensor.find_by uid: param(:sensor)
      pulses = Integer(param(:value))
    rescue => e
      halt 400, e.message
    end

    time = Time.at((params[:time] || Time.now).to_i)
    logger.info "energy sensor: #{sensor}, pulses: #{pulses}, time: #{time}"
    WattageValue.create(sensor, time, pulses)
  end

  # curl -X POST -d "sensor=1&value=123.235&time=12345" http://localhost:4004/temperature
  post '/value' do
    begin
      sensor = EnergySensor.find_by uid: param(:sensor)
      value = Float(param(:value))
    rescue => e
      halt 400, e.message
    end

    time = Time.at((params[:time] || Time.now).to_i)
    logger.info "sensor: #{sensor}, value: #{value}, time: #{time}"
    WattageValue.create_value(sensor, time, value)
  end

  # curl http://localhost:4004/sensors
  get '/sensors' do
    content_type :json
    Sensor.all.map(&:to_json)
  end

  # curl http://localhost:4004/sensors/:name
  get '/sensor/:name' do
    content_type :json
    Sensor.find_by(name: param(:name)).to_json rescue halt 404, 'Sensor not found'
  end

  # curl -X POST -d "name=Test&uid=123" http://localhost:4004/sensor
  post '/sensor' do
    name = param :name
    uid = param :uid

    type = params[:type] == 'energy' ? EnergySensor : Sensor

    begin
      type.find_or_create_by!(name: name, uid: uid)
    rescue => e
      halt 500, e.message
    end
  end

  # curl http://localhost:4004/
  get '/:datefrom?/?:dateto?' do
    from = params[:datefrom] ? Date.parse(params[:datefrom]) : 1.day.ago
    to = params[:dateto] ? Date.parse(params[:dateto]) : from + 2.day
    @data = get_metrics(from, to).to_json
    erb :index
  end

  private

  # Require that a specific parameter has been specified
  def param(name)
    params[name] or halt 400, "#{name} required!"
  end

  def get_energies(first, last)
    WattageMetric.where(sensor_id: EnergySensor.first.id)
      .and(:date.gte => first)
      .and(:date.lt => last)
      .pluck(:date, :pulses)
      .each_cons(2).map {|a| [a[1][0], (a[1][1] - a[0][1])/10000.0] }
  end

  def get_all_energies(first,last)
    names = EnergySensor.pluck(:id, :name).to_h

    metrics = WattageMetric.where(:date.gte => first).and(:date.lt => last).and(:pulses.gt => 0)
      .pluck(:date, :pulses, :sensor)
      .group_by{|metric| names[metric[2]] }
      .map{|name,metrics| [name, metrics.each_cons(2).map {|pair| [pair[1][0], (pair[1][1] - pair[0][1])/10000.0] } ]}.to_h

    metrics["Hush\u00E5llsel"] = metrics["Elm\u00E4tare"].map{|m| [m[0], m[1] - (metrics["Elbil"].find{|b| b[0] == m[0] }[1] rescue 0)] }
    metrics
  end

  def get_todays_metrics
    get_metrics(1.day.ago, 1.day.from_now)
  end

  def get_metrics(first, last)
    metrics = Metric.where(:date.gte => first).and(:date.lt => last)
      .order_by(_type: :asc)
      .group_by(&:_type)
      .each_with_index.map {|(type, metrics), i|
        metrics.map { |m| {sensor: m.sensor.name, values: m.values_arr.compact.to_h }}
        .group_by { |h| h[:sensor] }
        .map { |sensor, vals| {
          name: sensor,
          type: 'spline',
          yAxis: i,
          data: vals.map { |v| v[:values].select {|time| time > first }
                                         .map { |time, value| [time.to_i*1000, value] }}.to_a
                                  .sort_by { |values| values[0]||[] }
                     .map(&:to_a).flatten(1)}}
        .reject {|metric| metric[:data].empty? }
        #.each {|metric| metric[:data].last[0] = Time.now.to_i*1000 }
      }.flatten
      heat = get_heat_spline(first,last)
      if heat
        metrics << heat
      else
        metrics
      end
  end

  def get_available_heat(from, to)
      Sensor.where(name: "Varmvatten").first.metrics.where(:date.gte => from).and(:date.lt => to) # Hämta alla metric-objekt
        .map(&:values_arr).inject(:merge) # Slå samman deras värden till en lång lista
        .each_cons(3).select {|a,b,c| b[1] > a[1] && b[1] > c[1] }.map{|a,b,c| b}.to_h # Hitta alla lokala maximum
        .sort_by(&:last).reverse.to_h # Sortera i värdeordning
        .inject([]){|r,e| r.empty? || r.last.first < e.first ? r << e : r }.to_h # Plocka i datumordning
  end

  def get_heat_spline(from, to)
    data = get_available_heat(from, to)
            .select {|date,values| date > from } # Ta bara med värden som är upp till 24 h gamla
            .map{|date,value| [date.to_i*1000, value] }[0..-2] # Hoppa över sista värdet, det är sällan pålitligt
    if data.size > 1
      { name: 'Toppen av tanken',
        type: 'spline',
        yAxis: 0,
        data: data }
    end
  end

  def get_desired_heat(curve, offset, temp)
    value = CURVES[curve] * temp + OFFSETS[curve] + offset
    [90, [20, value].max].min
  end

  def get_forecast
    doc = Nokogiri::XML(open(settings.prognose_url))
    temperatures = doc.xpath('//time')[0..23].map{|n| [Time.parse(n[:from]).to_i*1000, n.search('temperature/@value').text.to_i] }
    desired_heat = temperatures.map{|time,temp| [time, get_desired_heat(settings.curve, settings.offset, temp)]}

    available = get_available_heat(1.day.ago, 1.day.from_now).to_a
    if available.size > 2
      d1 = available[0][0]
      d2 = available[-2][0]
      t1 = available[0][1]
      t2 = available[-2][1]
      loss_rate = (t2-t1)/(d2-d1) # Hur mycket tillgänlig värme förlorar vi i snitt per sekund

      available_heat = desired_heat.map(&:first).map{|time|
        timediff = time/1000 - d2.to_i
        tempdiff = loss_rate * timediff
        temp = t2 + tempdiff
        [time, temp]
      }
    else
      available_heat = desired_heat.map(&:first).map{|time| [time, available[0][1]] }
    end

    [{name: "Prognos utomhustemperatur", type: 'spline', yAxis: 0, data: temperatures},
     {name: "Önskad framledningstemperatur", type: 'spline', yAxis: 0, data: desired_heat},
     {name: "Uppskattad värmetillgång", type: 'spline', yAxis: 0, data: available_heat}]
  end

  # Ger antalet eldningar under ett år, grupperat per månad
  def get_fires(year)
    from = Date.new(year,1,1)
    to = Date.new(year,12,31)
    Sensor.where(name: 'Pannan').only(:id).first.metrics # Pann-sensorns metrics
      .where(:date.gte => from).and(:date.lt => to).only(:values, :date)
      .select {|metric| # Välj enbart ut de vars
        metric.values.map {|hour,minutes| # timmar vars
          minutes.map {|minute,values| values}}.flatten # minuter, vars värden
          .each_cons(2).any?{|p| p[0] <= 50 && p[1] >= 50 }} # har passerat 50 grader på väg upp
          .map(&:date) # Ta bara med datumen
          .group_by{|d| d.month } # Gruppera på månad
          .map{|month,metrics| [month,metrics.count] }.to_h # Räkna antal eldingar per månad
  end

  # Tar resultatet från get_fires() och summerar
  def sum_fires(fires)
    fires.map{|m,c| c}.inject(&:+)
  end
end
