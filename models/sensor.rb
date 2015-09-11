class Sensor
  include Mongoid::Document

  field :name, type: String

  has_many :metrics
end
