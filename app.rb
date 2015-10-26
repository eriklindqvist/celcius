require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'mongoid'
require 'json'
require 'tilt/erubis'

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|f| require f }

Mongoid.load!("mongoid.yml")
Mongo::Logger.logger.level = Logger::INFO

class Celcius < Sinatra::Base
  enable :logging

  # curl http://localhost:4004/
  get '/' do
    @data = get_todays_metrics.to_json
    erb :index
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

  # curl http://localhost:4004/sensors
  get '/sensors' do
    content_type :json
    Sensor.all.as_json.to_s
  end

  # curl http://localhost:4004/sensors/:name
  get '/sensor/:name' do
    content_type :json
    Sensor.find_by(name: param(:name)).as_json.to_s rescue halt 404, 'Sensor not found'
  end

  # curl -X POST -d "name=Test&uid=123" http://localhost:4004/sensor
  post '/sensor' do
    name = param :name
    uid = param :uid

    begin
      Sensor.find_or_create_by!(name: name, uid: uid)
    rescue => e
      halt 500, e.message
    end
  end

  private
  # Require that a specific parameter has been specified
  def param(name)
    params[name] or halt 400, "#{name} required!"
  end

  def get_todays_metrics
    Metric.where(:date.gte => 1.days.ago)
      .order_by(sensor: :desc)
      .map { |m| {sensor: m.sensor.name, values: m.values_arr.compact.to_h }}
      .group_by { |h| h[:sensor] }
      .map { |sensor, vals| {
        name: sensor,
        data: vals.map { |v| v[:values].select {|time| time > (Time.now - 1.day) }
                                       .map { |time, value| [time.to_i*1000, value] }}.to_a
                                .sort_by { |values| values[0] }
                   .map(&:to_a).flatten(1)}}
      .each {|metric| metric[:data].last[0] = Time.now.to_i*1000 }
  end
end
