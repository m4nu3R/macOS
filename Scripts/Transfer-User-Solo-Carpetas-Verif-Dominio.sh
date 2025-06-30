#!/bin/sh
#Archivo creado por Manuel Rangel para COX bajo un acuerdo de servicios con Decskill


# Revisión de estado de usuarios que no estén iniciados y tampoco archivos en uso.

#Determinar usuarios con la sesión disponible.
usuario="$(who|awk '/console/ {print $1}')"
usuarios="$(dscl . list /Users | grep -v '_')"


#Revisiones

#Revisa que si está en el dominio.
check4AD=$(/usr/bin/dscl localhost -list . | grep "Active Directory")
if [ "${check4AD}" != "Active Directory" ]; then
    echo "Este ordenador no está añadido al dominio, revisa el estado. "
    exit 1
fi

#Mensajes iniciales para confirmación del proceso
echo "El usuario iniciado es": $usuario
echo "Los usuarios registrados en el ordenador son:" $usuarios
echo "Ingrese el usuario origen de la información:" $origen
read origen
echo "Ingrese el usuario destino o a donde se transferirá la información:" $destino
read destino

#Determinar si está iniciada la sesión
#if [ "$usuario" = "$origen" ]; then
#    echo "$origen con sesión iniciada. Deteniendo"
#    echo "Este ordenador está iniciado con el usuario $origen, revisa si es correcto. "
#    exit 1
#else
#    if [ "$usuario" = "$destino" ]; then
#    echo "$destino con sesión iniciada. Deteniendo"
#    echo "Este ordenador está iniciado con el usuario $destino, revisa si es correcto. "
#    exit 1
#else
#echo "Ningun usuario con sesión iniciada, continuar."
#    #exit 0
#    fi
#fi

#Determinar si existen realmente los usuarios
if [ -d "/Users/$origen" ]; then 
result="/Users/$origen existe" echo "<result>El usuario $origen existe $result</result>"
else echo "<result>/Users/$origen no existe. Deteniendo.</result>"
exit 1
fi
if [ -d "/Users/$destino" ]; then 
result="/Users/$destino existe" echo "<result>El usuario $destino existe $result</result>"
else echo "<result>/Users/$destino no existe. Deteniendo.</result>"
exit 1
fi

# Renombrar Directorio Destino
#mv -f /Users/$destino /Users/$destino-antes
#echo "Renombrado /Users/$destino a /Users/$destino-antes"
# Trasladar directorio Escritorio de origen
cp -R "/Users/$origen/Desktop" "/Users/$destino/"
# Trasladar directorio Descargas de origen
cp -R "/Users/$origen/Downloads" "/Users/$destino/"
# Trasladar directorio Documents de origen
cp -R "/Users/$origen/Documents" "/Users/$destino/"
# Trasladar directorio Documents de origen
cp -R "/Users/$origen/Pictures" "/Users/$destino/"
echo "Archivos trasladados correctamente de /Users/$origen to /Users/$destino"
#Cambiar permisos de propiedad en el destino
chown -R $destino /Users/$destino
echo "Cambiada la propiedad de los archivos transferidos de $origen a $destino"
exit 0