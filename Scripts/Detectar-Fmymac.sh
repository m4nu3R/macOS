#!/bin/sh 
 
fmmToken=$(/usr/sbin/nvram -x -p | /usr/bin/grep fmm-mobileme-token-FMM) 
 
if [ -z "$fmmToken" ]; 
then 
echo "Buscar mi Mac, está deshabilitado" 
else 
echo "Buscar mi Mac, está habilitado $config" 
fi 