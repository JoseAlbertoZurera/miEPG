#!/bin/bash

# Limpieza inicial
rm -f EPG_temp* miEPG.xml 2>/dev/null

# Verificar archivos de entrada
[ ! -f "epgs.txt" ] && { echo "Error: epgs.txt no existe"; exit 1; }
[ ! -f "canales.txt" ] && { echo "Error: canales.txt no existe"; exit 1; }

# Descarga EPGs
echo "=== Descargando EPGs ==="
while IFS=, read -r epg; do
  [ -z "$epg" ] && continue
  
  echo "Procesando: $epg"
  if [[ "$epg" == *.gz ]]; then
    wget -q -O EPG_temp.gz "$epg" && {
      gzip -df EPG_temp.gz && {
        sed 's/></>\n</g' EPG_temp >> EPG_temp.xml
        echo "  ✓ Descargado y descomprimido correctamente"
      }
    } || echo "  ✗ Error al descargar/descomprimir"
  else
    wget -q -O EPG_temp.xml "$epg" && {
      sed -i 's/></>\n</g' EPG_temp.xml
      cat EPG_temp.xml >> EPG_combined.xml
      echo "  ✓ Descargado correctamente"
    } || echo "  ✗ Error al descargar"
  fi
done < epgs.txt

# Verifica si se descargó contenido
[ ! -f "EPG_temp.xml" ] && [ ! -f "EPG_combined.xml" ] && {
  echo "ERROR: No se pudo descargar ningún EPG válido"
  exit 1
}

# Procesar canales
echo -e "\n=== Procesando canales ==="
while IFS=, read -r old new logo; do
  [ -z "$old" ] && continue
  
  if grep -q "channel=\"$old\"" EPG_*.xml; then
    echo "Procesando: $old → $new"
    # Extraer y modificar canal
    sed -n "/<channel id=\"${old}\">/,/<\/channel>/p" EPG_*.xml > EPG_temp_channel.xml
    sed -i "s|<channel id=\"${old}\">|<channel id=\"${new}\">|; s|<display-name>${old}</display-name>|<display-name>${new}</display-name>|" EPG_temp_channel.xml
    [ -n "$logo" ] && sed -i "s|<icon src=\".*\"|<icon src=\"${logo}\"|" EPG_temp_channel.xml
    
    # Extraer programas
    sed -n "/<programme.*channel=\"${old}\"/,/<\/programme>/p" EPG_*.xml | \
      sed "s/channel=\"${old}\"/channel=\"${new}\"/g" >> EPG_temp_programs.xml
  else
    echo "Advertencia: Canal '$old' no encontrado"
  fi
done < canales.txt

# Genera miEPG.xml con todo el contenido del EPG descargado
echo '<?xml version="1.0" encoding="UTF-8"?>' > miEPG.xml
echo "<tv generator-info-name=\"miEPG $(date +'%d/%m/%Y %H:%M')\">" >> miEPG.xml
grep -E '<channel|<programme' EPG_temp.xml >> miEPG.xml
echo '</tv>' >> miEPG.xml

# Verificar resultado
if [ $(wc -l < miEPG.xml) -le 3 ]; then
  echo -e "\nERROR: El archivo de salida está casi vacío"
  echo "Posibles causas:"
  echo "1. Las URLs en epgs.txt no son válidas"
  echo "2. Los canales en canales.txt no coinciden con el EPG"
  echo "3. Problemas de permisos o espacio en disco"
else
  echo -e "\nÉxito: EPG generado en miEPG.xml"
  echo "Tamaño: $(du -h miEPG.xml | cut -f1)"
fi

# Limpieza
rm -f EPG_temp*
