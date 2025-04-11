#!/bin/bash

# Limpieza inicial
sed -i '/^ *$/d' epgs.txt
sed -i '/^ *$/d' canales.txt
rm -f EPG_temp*

# Descarga y combinación de EPGs
while IFS=, read -r epg
do
    extension="${epg##*.}"
    if [ "$extension" = "gz" ]; then
        echo "Descargando y descomprimiendo EPG: $epg"
        wget -O EPG_temp00.xml.gz -q "$epg"
        gzip -d -f EPG_temp00.xml.gz
    else
        echo "Descargando EPG: $epg"
        wget -O EPG_temp00.xml -q "$epg"
    fi
    cat EPG_temp00.xml >> EPG_temp.xml
    sed -i 's/></>\n</g' EPG_temp.xml
done < epgs.txt

# Procesamiento de canales (modificación de los listados en canales.txt)
while IFS=, read -r old new logo
do
    contar_channel="$(grep -c "channel=\"$old\"" EPG_temp.xml)"
    if [ "$contar_channel" -gt 1 ]; then
        sed -n "/<channel id=\"${old}\">/,/<\/channel>/p" EPG_temp.xml > EPG_temp01.xml
        sed -i '/<icon src/!d' EPG_temp01.xml
        if [ -n "$logo" ]; then
            echo "Nombre EPG: $old · Nuevo nombre: $new · Cambiando logo ··· $contar_channel coincidencias"
            echo '  </channel>' >> EPG_temp01.xml
            sed -i "1i\  <channel id=\"${new}\">" EPG_temp01.xml
            sed -i "2i\    <display-name>${new}</display-name>" EPG_temp01.xml
            sed -i "s#<icon src=.*#<icon src=\"${logo}\" />#" EPG_temp01.xml
            sed -i "3i\    <icon src=\"${logo}\" />" EPG_temp01.xml
        else
            echo "Nombre EPG: $old · Nuevo nombre: $new · Manteniendo logo ··· $contar_channel coincidencias"
            echo '  </channel>' >> EPG_temp01.xml
            sed -i "1i\  <channel id=\"${new}\">" EPG_temp01.xml
            sed -i "2i\    <display-name>${new}</display-name>" EPG_temp01.xml
        fi
        cat EPG_temp01.xml >> EPG_temp1.xml
        sed -i '$!N;/^\(.*\)\n\1$/!P;D' EPG_temp1.xml

        sed -n "/<programme.*\"${old}\"/,/<\/programme>/p" EPG_temp.xml > EPG_temp02.xml
        sed -i '/<programme/s/\">.*/\"/g' EPG_temp02.xml
        sed -i "s# channel=\"${old}\"##g" EPG_temp02.xml
        sed -i "/<programme/a EPG_temp channel=\"${new}\">" EPG_temp02.xml
        sed -i ':a;N;$!ba;s/\nEPG_temp//g' EPG_temp02.xml
        cat EPG_temp02.xml >> EPG_temp2.xml
    else
        echo "Saltando canal: $old ··· $contar_channel coincidencias"
    fi
done < canales.txt

# Incluir canales NO modificados (los que no están en canales.txt)
grep -Pzo '<channel id="[^"]+">.*?\n<\/channel>' EPG_temp.xml | while read -r line; do
    channel_id=$(echo "$line" | grep -oP 'channel id="\K[^"]+')
    if ! grep -q "$channel_id" canales.txt; then
        echo "$line" >> EPG_temp3.xml
    fi
done

# Incluir programas de canales NO modificados
grep -Pzo '<programme[^>]+channel="[^"]+">.*?\n<\/programme>' EPG_temp.xml | while read -r line; do
    channel_id=$(echo "$line" | grep -oP 'channel="\K[^"]+')
    if ! grep -q "$channel_id" canales.txt; then
        echo "$line" >> EPG_temp4.xml
    fi
done

# Generar EPG final
date_stamp=$(date +"%d/%m/%Y %R")
echo '<?xml version="1.0" encoding="UTF-8"?>' > miEPG.xml
echo "<tv generator-info-name=\"miEPG $date_stamp\" generator-info-url=\"https://github.com/davidmuma/miEPG\">" >> miEPG.xml
cat EPG_temp1.xml >> miEPG.xml  # Canales modificados
cat EPG_temp3.xml >> miEPG.xml  # Canales NO modificados
cat EPG_temp2.xml >> miEPG.xml  # Programas modificados
cat EPG_temp4.xml >> miEPG.xml  # Programas NO modificados
echo '</tv>' >> miEPG.xml

# Eliminar offsets horarios (+0200, etc.)
sed -i -E 's/(start|stop)="([^"]+)[+-][0-9]{4}"/\1="\2"/g' miEPG.xml

# Limpieza final
rm -f EPG_temp*
