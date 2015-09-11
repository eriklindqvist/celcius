require 'rubygems'
require 'bundler/setup'

require 'sinatra'
require 'mongoid'

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|f| require f }

Mongoid.load!("mongoid.yml")

class Celcius < Sinatra::Base
  # curl http://localhost:4004/
  get '/' do
    'Temperatures'
  end

  # curl -X POST -d "sensor=1&value=123.235&time=12345" http://localhost:4004/
  post '/' do
    begin
      sensor = BSON::ObjectId(param(:sensor))
      value = Float(param(:value))
      time = Time.at(param(:time).to_i)
    rescue => e
      halt 400, e.message
    end

    logger.info "sensor: #{sensor}, value: #{value}, time: #{time}"
  end

  def param(name)
    params[name] or halt 400, "#{name} required!"
  end
end
