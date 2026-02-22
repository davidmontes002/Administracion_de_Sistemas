#!/bin/bash

# Cargar funciones generales si las tienes
# source ../Lib/verificaciones.sh

listar_dominios() {

    ARCHIVO="/etc/bind/named.conf.local"

    # Verificar que el archivo exista
    if [ ! -f "$ARCHIVO" ]; then
        echo "No se encontro el archivo de configuracion de zonas."
        exit 1
    fi

    echo "======================================"
    echo "      DOMINIOS CONFIGURADOS EN DNS"
    echo "======================================"

    # Extraer nombres de zonas
    DOMINIOS=$(grep -E 'zone "' $ARCHIVO | awk -F'"' '{print $2}')

    if [ -z "$DOMINIOS" ]; then
        echo "No hay dominios configurados."
    else
        echo "$DOMINIOS" | nl -w2 -s") "
    fi

    echo "======================================"
}

# Ejecutar funcion
listar_dominios
read -p "Presione Enter para continuar..."