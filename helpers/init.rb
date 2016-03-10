%w(metric sensor value energy_sensor wattage_metric wattage_value).each {|f|
  require_relative "../models/#{f}"
}
