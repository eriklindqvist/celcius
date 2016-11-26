class WattageValue < Value
  def self.create(sensor_id, time, pulses)
    sensor = EnergySensor.find(sensor_id)
    metric = WattageMetric.find_or_create_by(sensor: sensor_id, date: time.to_date)

    t = time.dup
    until !!(metric.values[t.hour.to_s]||{})[t.min.to_s] || (t.hour == 0 && t.min == 0); t -= 60; end

    # TODO: Ensure first run works. This is probably not good enough.
    new_pulses = pulses - metric.pulses rescue 0
    seconds = time - metric.updated_at rescue 0

    watts = new_pulses*(360.0*(10000/sensor.rate)/seconds) unless seconds == 0

    current_value = (metric.values[t.hour.to_s]||{})[t.min.to_s]

    if watts && (current_value.nil? || (watts - current_value).abs > 0.1)
      metric.set_value(time, watts)
    end

    metric.pulses = pulses
    metric.save
  end
end
