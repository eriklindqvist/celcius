class Sensor
  include Mongoid::Document

  field :name, type: String
  field :uid, type: String

  has_many :metrics
end
