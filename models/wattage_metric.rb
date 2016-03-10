class WattageMetric < Metric
  include Mongoid::Timestamps

  field :pulses, type: Bignum
end
