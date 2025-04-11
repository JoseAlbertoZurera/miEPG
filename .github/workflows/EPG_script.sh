#!/bin/bash

# Limpieza inicial
sed -i '/^ *$/d' epgs.txt 2>/dev/null
sed -i '/^ *$/d' canales.txt 2>/dev/null
rm -f EPG_temp* miEPG.xml 2>/dev/null

# Descarga EPGs
echo "=== Descargando fuentes EPG ==="
while IFS=, read -r epg; do
  [[ -z "$epg" ]] && continue
  
  if [[ "$epg" == *.gz ]]; then
    echo "Descargando y descomprimiendo: $epg"
    wget -q -O EPG_temp.gz "$epg" && gzip -df EPG_temp.gz
    mv EPG_temp EPG_temp00.xml 2>/dev/null
  else
    echo "Descargando: $epg"
    wget -q -O EPG_temp00.xml "$epg"
  fi
  
  [ -f "EPG_temp00.xml" ] && {
    sed 's/></>\n</g' EPG_temp00.xml >> EPG_temp.xml
    rm -f EPG_temp00.xml
  }
done < epgs.txt

# Procesar canales
echo -e "\n=== Procesando canales ==="
[ -f "canales.txt" ] && while IFS=, read -r old new logo; do
  [[ -z "$old" ]] && continue
  
  if grep -q "channel=\"$old\"" EPG_temp.xml; then
    # Extraer canal
    sed -n "/<channel id=\"${old}\">/,/<\/channel>/p" EPG_temp.xml > EPG_temp1.xml
    
    # Modificar canal
    echo "Procesando: $old → $new"
    sed -i "s|<channel id=\"${old}\">|<channel id=\"${new}\">|g" EPG_temp1.xml
    sed -i "s|<display-name>${old}</display-name>|<display-name>${new}</display-name>|g" EPG_temp1.xml
    [ -n "$logo" ] && sed -i "s|<icon src=\".*\"|<icon src=\"${logo}\"|g" EPG_temp1.xml
    
    # Extraer programas
    sed -n "/<programme.*channel=\"${old}\".*/,/<\/programme>/p" EPG_temp.xml | \
      sed "s/channel=\"${old}\"/channel=\"${new}\"/g" >> EPG_temp2.xml
  else
    echo "Canal no encontrado: $old"
  fi
done < canales.txt

# Incluir canales no modificados
echo -e "\n=== Incluyendo canales no modificados ==="
grep -Pzo '<channel id="[^"]+">.*?</channel>' EPG_temp.xml | \
  while IFS= read -r line; do
    channel_id=$(echo "$line" | grep -oP 'channel id="\K[^"]+')
    if ! grep -q "^$channel_id," canales.txt 2>/dev/null; then
      echo "$line" >> EPG_temp3.xml
      # Extraer sus programas
      sed -n "/<programme.*channel=\"${channel_id}\".*/,/<\/programme>/p" EPG_temp.xml >> EPG_temp4.xml
    fi
  done

# Generar EPG final
echo -e "\n=== Generando miEPG.xml ==="
echo '<?xml version="1.0" encoding="UTF-8"?>' > miEPG.xml
echo "<tv generator-info-name=\"miEPG $(date +'%d/%m/%Y %R')\">" >> miEPG.xml

# Ordenar canales por nombre
for f in EPG_temp1.xml EPG_temp3.xml; do
  [ -f "$f" ] && sort -t'>' -k2,2 -u "$f" >> miEPG.xml
done

# Combinar programas y eliminar offsets horarios
for f in EPG_temp2.xml EPG_temp4.xml; do
  [ -f "$f" ] && sed -E 's/(start|stop)="([^"]+)[+-][0-9]{4}"/\1="\2"/g' "$f" >> miEPG.xml
done

echo '</tv>' >> miEPG.xml

# Limpieza
rm -f EPG_temp*
echo -e "\n=== Proceso completado ==="
echo "EPG generado en: miEPG.xml ($(du -h miEPG.xml | cut -f1))"
