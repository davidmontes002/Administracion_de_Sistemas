#!/bin/bash

BASE="/srv/ftp/grupos"

crear_grupo() {

    read -p "Nombre del grupo: " GRUPO

    if getent group "$GRUPO" > /dev/null; then
        echo "El grupo ya existe."
        return
    fi

    sudo groupadd "$GRUPO"

    sudo mkdir -p "$BASE/$GRUPO"
    sudo chown root:"$GRUPO" "$BASE/$GRUPO"
    sudo chmod 770 "$BASE/$GRUPO"

    # Activar SGID para heredar grupo
    sudo chmod g+s "$BASE/$GRUPO"

    echo "Grupo creado correctamente."
}

eliminar_grupo() {

    read -p "Nombre del grupo a eliminar: " GRUPO

    if ! getent group "$GRUPO" > /dev/null; then
        echo "El grupo no existe."
        return
    fi

    # Verificar si tiene usuarios asociados
    if getent group "$GRUPO" | grep -q ":"; then
        USERS=$(getent group "$GRUPO" | cut -d: -f4)
        if [ -n "$USERS" ]; then
            echo "El grupo tiene usuarios asociados:"
            echo "$USERS"
            echo "No se puede eliminar."
            return
        fi
    fi

    sudo groupdel "$GRUPO"
    sudo rm -rf "$BASE/$GRUPO"

    echo "Grupo eliminado correctamente."
}

# Crear grupos por defecto si no existen
for G in Reprobados Recursadores
do
    if ! getent group "$G" > /dev/null; then
        sudo groupadd "$G"
        sudo mkdir -p "$BASE/$G"
        sudo chown root:"$G" "$BASE/$G"
        sudo chmod 770 "$BASE/$G"
        sudo chmod g+s "$BASE/$G"
    fi
done
