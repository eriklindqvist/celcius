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
    # content_type :json
    # today = Date.today
    #
    # Metric.where(:date.gte => "ISODate('#{Date.today - 1}')").map{ |m| {sensor: m.sensor.name, values: m.values_arr.compact }}
    #
    # Metric.where(:date.gte => "ISODate('#{Date.today - 1}')").map{|m| m.values_arr.map{|v| {s: m.sensor.name, t: v[0], v: v[1] }}}.flatten.select{|e| e[:v] && e[:t] > 1.day.ago }.group_by{|v| v[:s] }
    #
    # Metric.where(:date.gte => "ISODate('#{Date.today - 1}')").map{ |m| {m.sensor.name => m.values_arr.compact }}
    #
    #   {sensor: metric.sensor.name, value: metric.values.select{|hour| (metric.date < today && hour.to_i >= Time.now.hour) || metric.date == today }
    #                            .map {|hour,minutes| minutes.select{ |minute, value| hour.to_i > Time.now.hour || (hour.to_i == Time.now.hour && minute.to_i >= Time.now.min ) }
    #       map {|minute, value| [metric.date.to_time + hour.to_i.hours + minute.to_i.minutes, value] }}.flatten(1).to_h.compact}}.group_by{|h| h[:sensor] }
    #minutes.select{|minute, value| ok = (hour.to_i > Time.now.hour || (hour.to_i == Time.now.hour && minute.to_i >= Time.now.min)); puts "#{hour}:#{minute} - #{ok}"; ok}
  end

  # curl -X POST -d "sensor=1&value=123.235&time=12345" http://localhost:4004/temperature
  post '/temperature' do
    begin
      sensor = Sensor.find param(:sensor)
      value = Float(param(:value))
      time = Time.at(param(:time).to_i)
    rescue => e
      halt 400, e.message
    end

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
