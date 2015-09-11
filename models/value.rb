class Value
  def self.create(sensor, time, value)
    metric = Metric.find_or_create_by(sensor: sensor, date: time.to_date)
    metric.values[time.hour.to_s][time.min.to_s] = value
    metric.save
  end
end