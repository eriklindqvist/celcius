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

    metric.set_value(time, watts) if watts

    metric.pulses = pulses
    metric.save
  end

  def self.create_value(sensor_id, time, value)
    sensor = EnergySensor.find(sensor_id)
    metric = WattageMetric.find_or_create_by(sensor: sensor_id, date: time.to_date)

    t = time.dup
    until !!(metric.values[t.hour.to_s]||{})[t.min.to_s] || (t.hour == 0 && t.min == 0); t -= 60; end

    existing_value = (metric.values[t.hour.to_s]||{})[t.min.to_s]
    values = metric.values.map{|h,vals| vals.map{|m,values| [DateTime.new(time.year, time.month, time.day, h.to_i, m.to_i, 0, time.zone), values] }}.flatten(1).to_h

    unless existing_value
      metric.set_value(time, value) if value

      last_time, last_value = values.to_a.last

      # Only allow update of fake pulses value if inserting at the end of the values array
      if last_time < time
        rate = sensor.rate || 10000

        hours = hours(last_time, time)
        kwh = (last_value * hours + ((last_value - value).abs * hours)/2)/1000

        pulses = kwh * rate

        metric.pulses += pulses
      end

      metric.save
    end
  end

  private
  # Level 2 notation just for fun.
  # Return difference in hours between two DateTime objects
  def hours(*times)
    times[0..1].map(&:to_time).reduce(&:-).abs / 3600
  end
end
