environment = ENV['RACK_ENV'] || 'development'

require 'rubygems'
require 'bundler/setup'
require 'mongoid'
require 'date'

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|f| require f }

Mongoid.load!("mongoid.yml", environment)
Mongo::Logger.logger.level = Logger::INFO

def parse_datalogger(filename)
  sensor = Sensor.find_or_create_by(name: "Jordkällaren")
  metrics = {}

  File.readlines(filename)[8..-1].each { |line|
    values = line.split
    time = DateTime.strptime(values[1..2].join(' '), '%m-%d-%Y %H:%M:%S').to_time rescue next

    metric = metrics[time.to_date] ||= Metric.find_or_create_by(date: time.to_date, sensor: sensor)
    metric.set_value(time, values[3])
  }

  metrics.each { |date, metric| metric.save }
  
  true
end
