class EnergySensor < Sensor
  field :rate, type: Integer, default: 10000
  field :group, type: String

  field :min, type: Integer, default: 0 # Prohibit negative values
  field :max, type: Integer, default: 2300 # 10 A * 230 W
end
