#!/bin/bash

# 1. Limpieza inicial
rm -f EPG_temp* miEPG.xml 2>/dev/null

# 2. Descargar EPG manteniendo saltos de línea originales
wget -q -O EPG_temp.xml "https://raw.githubusercontent.com/davidmuma/EPG_dobleM/master/guiaiptv.xml"

# 3. Formatear XML conservando estructura completa
sed -i 's/></>\n</g' EPG_temp.xml

# 4. Extraer canales completos (con toda su información)
grep -Pzo '<channel id="[^"]+">(\n|.)*?\n<\/channel>' EPG_temp.xml > EPG_channels.xml

# 5. Extraer programas completos (con todo su contenido interno)
grep -Pzo '<programme start="[^"]+" stop="[^"]+" channel="[^"]+">(\n|.)*?\n<\/programme>' EPG_temp.xml > EPG_programs.xml

# 6. Corregir offsets horarios (manteniendo 1 espacio y cambiando a +0000)
sed -i -E 's/(start|stop)="([0-9]{14})[[:space:]]*[+-][0-9]{4}"/\1="\2 +0000"/g' EPG_programs.xml

# 7. Generar EPG final
echo '<?xml version="1.0" encoding="UTF-8"?>' > miEPG.xml
echo "<tv generator-info-name=\"miEPG $(date +'%d/%m/%Y %H:%M')\">" >> miEPG.xml

# 8. Añadir contenido conservando saltos de línea y formato
cat EPG_channels.xml >> miEPG.xml
cat EPG_programs.xml >> miEPG.xml

echo '</tv>' >> miEPG.xml

# 9. Limpieza y verificación
rm -f EPG_temp*
echo "EPG generado correctamente en miEPG.xml"
echo "Estadísticas:"
echo "- Canales: $(grep -c '<channel' miEPG.xml)"
echo "- Programas: $(grep -c '<programme' miEPG.xml)"
echo "- Tamaño: $(du -sh miEPG.xml | cut -f1)"