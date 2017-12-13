class Sensor
  include Mongoid::Document

  field :name, type: String
  field :uid, type: String

  field :min, type: Integer, default: -30
  field :max, type: Integer, default: 100

  has_many :metrics

  def to_json
    { name: self.name,
      uid: self.uid,
      current: current_value }.to_json
  end

  def current_value
    metrics.where(date: Time.now.to_date).first.values.to_a.last.last.values.last rescue nil
  end

  def range
    (min..max)
  end
end
