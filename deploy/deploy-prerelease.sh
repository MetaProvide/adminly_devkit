#!/usr/bin/env bash
app_name=""
api_endpoint="https://api.github.com/repos/MetaProvide/${app_name}/releases"

json=$(curl -sS "$api_endpoint")

for row in $(echo "${json}" | jq -r '.[] | @base64'); do
    _jq() {
    	echo "${row}" | base64 --decode | jq -r "${1}"
    }
	if [ "$(_jq '.prerelease')" == "true" ] ; then
		url=$(_jq '.assets[0].browser_download_url')
		break
	fi
done

curl -sSLo ./$app_name.tar.gz "$url"
docker exec -u www-data ship_nextcloud_1 php occ app:disable $app_name
docker exec -u www-data ship_nextcloud_1 php occ app:remove $app_name

tar -xf ./$app_name.tar.gz
chown -R www-data:www-data ./$app_name

mv ./$app_name /var/lib/docker/volumes/ship_apps/_data/

rm ./$app_name.tar.gz

docker exec -u www-data ship_nextcloud_1 php occ app:enable $app_name
