require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'mongoid'
require 'json'
require 'tilt/erubis'

require_relative 'helpers/init'

Mongoid.load!("mongoid.yml")
Mongo::Logger.logger.level = Logger::INFO

class Celcius < Sinatra::Base
  enable :logging

  # curl http://localhost:4004/
  get '/' do
    @data = get_todays_metrics.to_json
    erb :index
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
    last = Date.new(date.year, date.month+1, 1)
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

  get '/data' do
    content_type :json
    get_todays_metrics.to_json
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

# curl -X POST -d "sensor=1&value=12345" http://localhost:4004/pulses
  post '/pulses' do
    begin
      sensor = EnergySensor.find_by uid: param(:sensor)
      pulses = Integer(param(:value))
    rescue => e
      halt 400, e.message
    end

    time = Time.now
    logger.info "energy sensor: #{sensor}, pulses: #{pulses}, time: #{time}"
    WattageValue.create(sensor, time, pulses)
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


  #private
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

    metrics = WattageMetric.where(:date.gte => first).and(:date.lt => last)
      .pluck(:date, :pulses, :sensor)
      .group_by{|metric| names[metric[2]] }
      .map{|name,metrics| [name, metrics.each_cons(2).map {|pair| [pair[1][0], (pair[1][1] - pair[0][1])/10000.0] } ]}.to_h

    metrics["Hush\u00E5llsel"] = metrics["Elm\u00E4tare"].map{|m| [m[0], m[1] - (metrics["Elbil"].find{|b| b[0] == m[0] }[1] rescue 0)] }
    metrics
  end

  def get_todays_metrics
    Metric.where(:date.gte => 1.days.ago)
      .order_by(_type: :asc)
      .group_by(&:_type)
      .each_with_index.map {|(type, metrics), i|
        metrics.map { |m| {sensor: m.sensor.name, values: m.values_arr.compact.to_h }}
        .group_by { |h| h[:sensor] }
        .map { |sensor, vals| {
          name: sensor,
          type: 'spline',
          yAxis: i,
          data: vals.map { |v| v[:values].select {|time| time > (Time.now - 1.day) }
                                         .map { |time, value| [time.to_i*1000, value] }}.to_a
                                  .sort_by { |values| values[0]||[] }
                     .map(&:to_a).flatten(1)}}
        .each {|metric| metric[:data].last[0] = Time.now.to_i*1000 }
      }.flatten
  end
end
