class Metric
  include Mongoid::Document

  field :date, type: Date
  field :values, type: Hash, default: {}

  belongs_to :sensor

  def values_arr
    self.values.map {|hour, minutes| minutes.map {|minute, value| [self.date + hour.to_i.hours + minute.to_i.minutes, value] }}.flatten(1).to_h
  end

  def set_value(time, value)
    raise "Value out of bounds" if !sensor.range().include? value # value within range

    (values[time.hour.to_s]||={})[time.min.to_s] = value
  end
end
