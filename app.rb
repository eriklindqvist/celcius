require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'mongoid'
require 'json'
require 'tilt/erubis'

#Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|f| require f }
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
    content_type :json
    date = params[:date] ? Date.parse(params[:date]) : Date.today
    first = Date.new(date.year, date.month, 1) - 1
    last = Date.new(date.year, date.month+1, 1)
    get_energies(first, last).to_json
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
    metrics = EnergySensor.first.metrics.where(:date.gte => first).and(:date.lt => last)
    metrics[0..-2].map.with_index{|n,i|
      next_metric = metrics[i+1]
      [next_metric.date, (next_metric.pulses - n.pulses)/10000.0]
    }
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
