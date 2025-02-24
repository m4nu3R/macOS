#!/bin/bash
##
# Detección iCloud/
##
# Detección icloud/ sign-ins
mobileMeConfigs=`find /Users/ -name "MobileMeAccounts.plist" 2> /dev/null`
if [ ! -z "$mobileMeConfigs" ]; # Si la variable no está vacia, se encontrarán los archivos de configuración y los datos de la cuenta asignada.
then
	for configFile in $mobileMeConfigs;
	do
		echo "Cuenta iCloud: Encontrada en la ruta $configFile. Revisando"
		# Obteniendo la información de la cuenta y los IDs del archivo si existen.
		config=`defaults read $configFile 2>/dev/null | grep "AccountID =" | perl -pe 's/^\s*AccountID =\s"//' | perl -pe 's/";//'`
		if [ ! -z "$config" ];
		then
			echo "Cuenta iCloud: Se encuentró una cuenta asociada al perfil.  Revisar!"
			echo "Cuenta asociada $config encontrada en: $configFile"
			
		else
			echo "No se encontró información de cuenta de iCloud, Ignorar
            ."
		fi
	done
fi