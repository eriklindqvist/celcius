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
    # TODO: Aggregate all values for all sensors in JSON-format
    #metrics = Metric.where(:date.gte => "ISODate('#{1.day.ago.to_date}')", :date.lte => "ISODate('#{(Time.now+1.day).to_date}')").group_by(&:sensor...
    #values.map {|h,mins| mins.map {|min,val| [Time.parse("#{m.date} #{h}:#{min}").to_i*1000,val] }}.flatten(1)
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
