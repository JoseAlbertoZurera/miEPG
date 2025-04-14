#!/bin/bash

# 1. Limpieza inicial
rm -f EPG_temp* miEPG.xml 2>/dev/null

# 2. Descargar EPG (ejemplo con tu URL)
wget -q -O EPG_temp.xml "https://raw.githubusercontent.com/davidmuma/EPG_dobleM/master/guiaiptv.xml"

# 3. Formatear XML (un tag por línea)
sed -i 's/></>\n</g' EPG_temp.xml

# 4. Extraer TODOS los canales completos (con su información)
sed -n '/<channel /,/<\/channel>/p' EPG_temp.xml > EPG_channels.xml

# 5. Extraer TODA la programación completa (con todos los atributos)
sed -n '/<programme /,/<\/programme>/p' EPG_temp.xml > EPG_programs.xml

# 6. Generar EPG final con todo el contenido
echo '<?xml version="1.0" encoding="UTF-8"?>' > miEPG.xml
echo "<tv generator-info-name=\"miEPG $(date +'%d/%m/%Y %H:%M')\">" >> miEPG.xml

# 7. Añadir canales y programación (modificando offsets horarios)
cat EPG_channels.xml >> miEPG.xml
sed -E 's/(start|stop)="([0-9]{14})[[:space:]]*[+-][0-9]{4}"/\1="\2 -0200"/g' EPG_programs.xml >> miEPG.xml

echo '</tv>' >> miEPG.xml

# 8. Limpieza y verificación
rm -f EPG_temp*
echo "EPG generado en miEPG.xml"
echo "Canales: $(grep -c '<channel' miEPG.xml)"
echo "Programas: $(grep -c '<programme' miEPG.xml)"