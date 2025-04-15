#!/bin/bash

# 1. Limpieza inicial
rm -f EPG_temp* miEPG.xml 2>/dev/null

# 2. Descargar EPG
wget -q -O EPG_temp.xml "https://raw.githubusercontent.com/davidmuma/EPG_dobleM/master/guiaiptv.xml"

# 3. Formatear XML (método alternativo más seguro)
xmlstarlet fo -R EPG_temp.xml > EPG_temp_formatted.xml 2>/dev/null || {
    # Si xmlstarlet falla, usamos sed básico
    sed -i 's/></>\n</g' EPG_temp.xml
    cp EPG_temp.xml EPG_temp_formatted.xml
}

# 4. Extraer canales (método seguro para archivos grandes)
awk '/<channel / {flag=1; buffer=$0; next} 
     flag {buffer = buffer ORS $0} 
     /<\/channel>/ {print buffer; flag=0; buffer=""}' EPG_temp_formatted.xml > EPG_channels.xml

# 5. Extraer programas (método seguro para archivos grandes)
awk '/<programme / {flag=1; buffer=$0; next} 
     flag {buffer = buffer ORS $0} 
     /<\/programme>/ {print buffer; flag=0; buffer=""}' EPG_temp_formatted.xml > EPG_programs.xml

# 6. Corregir offsets horarios
sed -i -E 's/(start|stop)="([0-9]{14})[[:space:]]*[+-][0-9]{4}"/\1="\2 +0000"/g' EPG_programs.xml

# 7. Generar EPG final
echo '<?xml version="1.0" encoding="UTF-8"?>' > miEPG.xml
echo "<tv generator-info-name=\"miEPG $(date +'%d/%m/%Y %H:%M')\">" >> miEPG.xml
cat EPG_channels.xml EPG_programs.xml >> miEPG.xml
echo '</tv>' >> miEPG.xml

# 8. Estadísticas reales (método más preciso)
channels_count=$(grep -c '<channel ' miEPG.xml)
programs_count=$(grep -c '<programme ' miEPG.xml)

# 9. Limpieza y verificación
rm -f EPG_temp*
echo "EPG generado correctamente en miEPG.xml"
echo "Estadísticas:"
echo "- Canales: $channels_count"
echo "- Programas: $programs_count"
echo "- Tamaño: $(du -sh miEPG.xml | cut -f1)"