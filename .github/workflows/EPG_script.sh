#!/bin/bash

# 1. Limpieza inicial
rm -f EPG_temp* miEPG.xml 2>/dev/null

# 2. Descargar EPG
wget -q -O EPG_temp.xml "https://raw.githubusercontent.com/davidmuma/EPG_dobleM/master/guiaiptv.xml"

# 3. Formatear XML conservando estructura
sed -i 's/></>\n</g' EPG_temp.xml

# 4. Extraer TODOS los canales completos
awk '/<channel / {flag=1; buffer=$0; next} 
     flag {buffer = buffer ORS $0} 
     /<\/channel>/ {print buffer; flag=0; buffer=""}' EPG_temp.xml > EPG_channels.xml

# 5. Extraer TODA la programación COMPLETA (con tags internos)
awk '
BEGIN {RS="</programme>"; FS="\n"}
{
    if ($0 ~ /<programme /) {
        buffer = $0
        for (i=2; i<=NF; i++) {
            buffer = buffer ORS $i
        }
        print buffer "</programme>"
    }
}' EPG_temp.xml > EPG_programs.xml

# 6. Corregir offsets horarios (manteniendo formato original)
sed -i -E '
/<programme / {
    s/(start|stop)="([0-9]{14})[[:space:]]*[+-][0-9]{4}"/\1="\2 -0200"/g
}' EPG_programs.xml

# 7. Generar EPG final
echo '<?xml version="1.0" encoding="UTF-8"?>' > miEPG.xml
echo "<tv generator-info-name=\"miEPG $(date +'%d/%m/%Y %H:%M')\">" >> miEPG.xml
cat EPG_channels.xml EPG_programs.xml >> miEPG.xml
echo '</tv>' >> miEPG.xml

# 8. Verificación de contenido
echo "=== Verificación de contenido ==="
echo "Primer programa completo:"
grep -A10 -m1 '<programme ' miEPG.xml | head -15
echo -e "\nEstadísticas finales:"
echo "- Canales: $(grep -c '<channel ' miEPG.xml)"
echo "- Programas: $(grep -c '<programme ' miEPG.xml)"
echo "- Tamaño: $(du -sh miEPG.xml | cut -f1)"