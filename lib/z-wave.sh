user="admin"
pass="*****"

# Radiatorpump, Laddomat, Frysen, Diskmaskinen
watt_sensors=("ZWayVDev_zway_14-2-50-2" "ZWayVDev_zway_14-1-50-2" "ZWayVDev_zway_9-0-50-2" "ZWayVDev_zway_10-0-50-2" "ZWayVDev_zway_37-1-50-2" "ZWayVDev_zway_29-1-50-2")
temp_sensors=("ZWayVDev_zway_6-0-49-1")

api="http://find.z-wave.me/ZAutomation/api/v1"
url="http://celcius:9393"

# Logga in
data="{\"form\": true, \"login\": \"$user\", \"password\": \"$pass\", \"keepme\": false, \"default_ui\": 1}"
curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d "$data" "$api/login" -c cookie.txt > /dev/null

# Begär sensor-värde
for watt_sensor in "${watt_sensors[@]}"
do
  json=`curl -s "$api/devices/$watt_sensor" -b cookie.txt`
  update=`echo $json | awk 'match($0, /\"updateTime\":([0-9]+)/, a) {print a[1]}'`
  value=`echo $json | awk 'match($1, /\"level\":([0-9]+(\.[0-9]{1,2})?)/, a) {print a[1]}'`
  curl -X POST -d "sensor=$watt_sensor&value=$value&time=$update" "$url/value"
done

for temp_sensor in "${temp_sensors[@]}"
do
  json=`curl -s "$api/devices/$temp_sensor" -b cookie.txt`
  update=`echo $json | awk 'match($0, /\"updateTime\":([0-9]+)/, a) {print a[1]}'`
  value=`echo $json | awk 'match($1, /\"level\":([0-9]+(\.[0-9]{1,2})?)/, a) {print a[1]}'`
  curl -X POST -d "sensor=$temp_sensor&value=$value&time=$update" "$url/temperature"
done
