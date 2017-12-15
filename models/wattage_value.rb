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

    metric.set_value(time, watts) if watts

    metric.pulses = pulses
    metric.save
  end

  def self.create_value(sensor_id, time, value)
    sensor = EnergySensor.find(sensor_id)
    metric = WattageMetric.find_or_create_by(sensor: sensor_id, date: time.to_date)

    t = time.dup
    until !!(metric.values[t.hour.to_s]||{})[t.min.to_s] || (t.hour == 0 && t.min == 0); t -= 60; end

    existing_value = (metric.values[time.hour.to_s]||{})[time.min.to_s]

    unless existing_value
      values = metric.values.map{|h,vals| vals.map{|m,values| [DateTime.new(time.year, time.month, time.day, h.to_i, m.to_i, 0, time.zone), values] }}.flatten(1).to_h

      last_time, last_value = values.to_a.last

      minute_ago = time - 1.minute

      previous_value = values[minute_ago]

      if !previous_value && last_value && last_time < minute_ago
        metric.set_value(minute_ago, last_value)
      end

      metric.set_value(time, value) if value

      # Only allow update of fake pulses value if inserting at the end of the values array
      if !last_time
        metric.pulses = WattageMetric.where(sensor: sensor_id, :date.lt => metric.date, :pulses.gt => 0).only(:date, :pulses).desc(:date).limit(1).pluck(:pulses).first || 0
      elsif last_time < time
        rate = sensor.rate || 10000

        if !previous_value
          hours1 = [last_time, minute_ago].map(&:to_time).reduce(&:-).abs / 3600
          kwh1 = (last_value * hours1)/1000

          hours2 = [minute_ago, time].map(&:to_time).reduce(&:-).abs / 3600
          kwh2 = (last_value * hours2 + ((last_value - value).abs * hours2)/2)/1000

          pulses = (kwh1 * rate) + (kwh2 * rate)
        else
          hours = [last_time, time].map(&:to_time).reduce(&:-).abs / 3600
          kwh = (last_value * hours + ((last_value - value).abs * hours)/2)/1000

          pulses = kwh * rate
        end

        metric.pulses = (metric.pulses || 0) + pulses
      end

      metric.save
    end
  end
end
