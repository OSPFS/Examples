#!/bin/bash
#
# Для разрешения доступа из какой либо страны запустить скрипт с кодом страны (коды находятся в файле zone_country_codes.txt в скобках)
# Пример: ./asterisk_ipset FR скачает список сетей Франции и добавит в ipset
#
# Для удаления страны из списка, достаточно удалить zone-файл этой страны и запустить скрипт
# Скрипт без параметров добавляет сети РФ, сети стран zone-файлы которых присутствуют в директории и zone.white_list.txt
#
# В whitelist можно добавлять как сети типа 192.168.232.0/24 так и отдельные IP адреса 192.168.232.15
#

cd /usr/local/bin

iptables -F

#rm -f IP2LOCATION-LITE-DB1.CSV

COUNTRY=$(grep -i "("$1")" zone_country_codes.txt)

# Проверяем наличие ipseta
ipset list asterisk_ipset 2>&1 > /dev/null
if [ $? -ne 0 ]
then
  echo "There is no asterisk_ipset, creating..."
  ipset create asterisk_ipset hash:net
fi

# Очищаем ipset
ipset flush asterisk_ipset

# Скачиваем зоны

echo
echo "Download Zones"
wget "http://www.ip2location.com/download/?token=QaBrGbXMmsqN8T3j8h7nlEKWhII8wJdmTPOA0LnndOalHeFQwMdRrXOIGxRdg5Aa&file=DB1LITE" --output-document=/usr/local/bin/tmp.zip
unzip /usr/local/bin/tmp.zip IP2LOCATION-LITE-DB1.CSV

# Обновляем постоянные зоны

cat /usr/local/bin/IP2LOCATION-LITE-DB1.CSV|grep -e "RU" > zone.RU-aggregated.CSV
cat /usr/local/bin/IP2LOCATION-LITE-DB1.CSV|grep -e "ES" > zone.ES-aggregated.CSV
cat /usr/local/bin/IP2LOCATION-LITE-DB1.CSV|grep -e "LV" > zone.LV-aggregated.CSV
/usr/local/bin/converter.php -cidr /usr/local/bin/zone.RU-aggregated.CSV /usr/local/bin/zone.RU-aggregated.tmp
/usr/local/bin/converter.php -cidr /usr/local/bin/zone.ES-aggregated.CSV /usr/local/bin/zone.ES-aggregated.tmp
/usr/local/bin/converter.php -cidr /usr/local/bin/zone.LV-aggregated.CSV /usr/local/bin/zone.LV-aggregated.tmp
cat zone.RU-aggregated.tmp|cut -d',' -f1|tr -d '"' > /usr/local/bin/zone.RU-aggregated.txt
cat zone.ES-aggregated.tmp|cut -d',' -f1|tr -d '"' > /usr/local/bin/zone.ES-aggregated.txt
cat zone.LV-aggregated.tmp|cut -d',' -f1|tr -d '"' > /usr/local/bin/zone.LV-aggregated.txt

echo 

# Скачиваем зону из параметров командной строки (если указан параметр)
if [ "$1" != "" ]; then
    ZONE=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    echo
#    echo Download "$COUNTRY" Zone
    cat IP2LOCATION-LITE-DB1.CSV |grep -e "$ZONE" > zone."$ZONE"-aggregated.CSV
    /usr/local/bin/converter.php -cidr /usr/local/bin/zone."$ZONE"-aggregated.CSV /usr/local/bin/zone."$ZONE"-aggregated.tmp
    cat zone."$ZONE"-aggregated.tmp|cut -d',' -f1|tr -d '"' > zone."$ZONE"-aggregated.txt
    echo
fi

# Загружаем зоны в ipset из файлов *.zone
for zone_files in zone.*.txt
 do
  COUNTRY=$(echo $zone_files|cut -d '.' -f2|cut -d '-' -f1)
  COUNTRY=$(grep -i "($COUNTRY)" zone_country_codes.txt)
  printf "%-45s %s\n" "Loading $COUNTRY" "file: $zone_files"
  for d in $(cat $zone_files); do ipset -A asterisk_ipset $d; done
 done

ipset save > /etc/sysconfig/ipset.list
rm -f *aggregated.tmp
rm -f *aggregated.CSV
rm -f IP2LOCATION-LITE-DB1.CSV

iptables-restore < /etc/sysconfig/iptables
