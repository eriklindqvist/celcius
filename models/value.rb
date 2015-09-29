class Value
  def self.create(sensor, time, value)
    metric = Metric.find_or_create_by(sensor: sensor, date: time.to_date)

    t = time.dup
    until !!(metric.values[t.hour.to_s]||{})[t.min.to_s] || (t.hour == 0 && t.min == 0); t -= 60; end
    current_value = (metric.values[t.hour.to_s]||{})[t.min.to_s]

    unless (value - current_value).abs < 0.1
      metric.set_value(time, value)
      metric.save
    end
  end
end
