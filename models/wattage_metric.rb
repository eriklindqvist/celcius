class WattageMetric < Metric
  include Mongoid::Timestamps

  field :pulses, type: Integer
end
