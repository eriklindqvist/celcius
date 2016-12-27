user="admin"
pass="*****"

sensor="ZWayVDev_zway_6-1-50-2"

api="http://10.0.0.185:8083/ZAutomation/api/v1"
url="http://localhost:9393/value"

# Logga in
data="{\"form\": true, \"login\": \"$user\", \"password\": \"$pass\", \"keepme\": false, \"default_ui\": 1}"
curl -s -i -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d "$data" "$api/login" -c cookie.txt > /dev/null

# Begär sensor-värde
json=`curl -s "$api/devices/$sensor" -b cookie.txt`
update=`echo $json | awk 'match($0, /\"updateTime\":([0-9]+)/, a) {print a[1]}'`
value=`echo $json | awk 'match($1, /\"level\":([0-9]+(\.[0-9]{1,2})?)/, a) {print a[1]}'`

echo "update: $update      value: $value"
curl -X POST -d "sensor=$sensor&value=$value&time=$update" $url
