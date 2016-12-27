user="admin"
pass="*****"

watt_sensor="ZWayVDev_zway_6-1-50-2"
temp_sensor="ZWayVDev_zway_6-0-49-1"

api="http://10.0.0.185:8083/ZAutomation/api/v1"
url="http://localhost:9393"

# Logga in
data="{\"form\": true, \"login\": \"$user\", \"password\": \"$pass\", \"keepme\": false, \"default_ui\": 1}"
curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d "$data" "$api/login" -c cookie.txt > /dev/null

# Begär sensor-värde
json=`curl -s "$api/devices/$watt_sensor" -b cookie.txt`
update=`echo $json | awk 'match($0, /\"updateTime\":([0-9]+)/, a) {print a[1]}'`
value=`echo $json | awk 'match($1, /\"level\":([0-9]+(\.[0-9]{1,2})?)/, a) {print a[1]}'`
curl -X POST -d "sensor=$watt_sensor&value=$value&time=$update" "$url/value"

json=`curl -s "$api/devices/$temp_sensor" -b cookie.txt`
update=`echo $json | awk 'match($0, /\"updateTime\":([0-9]+)/, a) {print a[1]}'`
value=`echo $json | awk 'match($1, /\"level\":([0-9]+(\.[0-9]{1,2})?)/, a) {print a[1]}'`
curl -X POST -d "sensor=$temp_sensor&value=$value&time=$update" "$url/temperature"
