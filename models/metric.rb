class Metric
  include Mongoid::Document

  field :date, type: Date
  field :values, type: Array, default: ->{ 24.times.map { |i| [i.to_s, 60.times.map {|j| [j.to_s, nil] }.to_h ] }.to_h }

  belongs_to :sensor
end