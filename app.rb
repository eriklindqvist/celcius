require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'mongoid'
require 'json'

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|f| require f }

Mongoid.load!("mongoid.yml")

class Celcius < Sinatra::Base

  # curl http://localhost:4004/
  get '/' do
    content_type :json

    Metric.where(:date.gte => "ISODate('#{Date.today - 1}')")
        .map{ |m| {sensor: m.sensor.name, values: m.values_arr.compact.to_h }}
        .group_by{|h| h[:sensor] }
        .map{|sensor,vals| [sensor, vals.map{|v| v[:values]
                                                     .select{|time,value| time > (Time.now - 1.day)}
                                                     .map{|time, value| [time.to_i*1000, value]}}
                                        .map(&:to_a).flatten(1)]}.to_h.to_json
  end

  # curl -X POST -d "sensor=1&value=123.235&time=12345" http://localhost:4004/temperature
  post '/temperature' do
    begin
      sensor = Sensor.find param(:sensor)
      value = Float(param(:value))
    rescue => e
      halt 400, e.message
    end

    time = Time.at(param(:time).to_i) rescue Time.now

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

  # curl -X POST -d "name=Test" http://localhost:4004/sensor
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
end
