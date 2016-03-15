class Sensor
  include Mongoid::Document

  field :name, type: String
  field :uid, type: String

  has_many :metrics

  def to_json
    t = Time.now
    value = metrics.where(date: t.to_date).first.values.to_a.last.last.values.last rescue nil
    { name: self.name,
      uid: self.uid,
      current: value }.to_json
  end
end
