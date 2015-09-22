ENV['RACK_ENV'] ||= 'migration'

require 'rubygems'
require 'bundler/setup'

require 'mongoid'

require 'active_record'

Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|f| require f }

Mongoid.load!("mongoid.yml")

ActiveRecord::Base.establish_connection(adapter: 'mysql', host: '10.0.0.60', database: 'temperatures', username: 'migrate', password: 'mongo')

module Migrate
  class Sensor < ActiveRecord::Base
    # id
    # description
    # uid
  end

  class Temperature < ActiveRecord::Base
    # id
    # time
    # sensor
    # temp
  end
end

sensors = Migrate::Sensor.all.map {|s| [s.id, Sensor.find_or_create_by(name: s.description, uid: s.uid)] }.to_h
metrics = sensors.keys.map{|k| [k,{}] }.to_h
i = 0

Migrate::Temperature.where("time > '#{10.days.ago.to_date.to_s}'").find_each do |t|
  sensor = metrics[t.sensor]
  unless sensor
    puts "sensor #{t.sensor} not found!"
  else
    metric = sensor[t.time.to_date.to_s] ||= Metric.find_or_create_by(date: t.time.to_date, sensor: sensors[t.sensor])
    metric.set_value(t.time, t.temp)
    i += 1
    if i % 100 == 0
      print "\rread #{i} temperatures. currently at date #{t.time.to_date}"
      $stdout.flush
    end
  end
end

puts "#{i} temperatures read"

metrics.each {|sensor, dates| dates.each {|date, metric| metric.save }}