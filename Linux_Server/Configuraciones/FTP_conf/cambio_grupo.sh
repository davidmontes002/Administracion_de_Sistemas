#!/bin/bash

BASE="/srv/ftp"

Cambiar_Grupo() {

    read -p "Usuario: " USER
    read -p "Nuevo grupo: " NUEVO

    # Validar usuario
    if ! id "$USER" &>/dev/null; then
        echo "El usuario no existe."
        return
    fi

    # Validar grupo
    if ! getent group "$NUEVO" > /dev/null; then
        echo "El grupo no existe."
        return
    fi

    # Mantener grupos existentes y añadir el nuevo
    sudo usermod -aG "$NUEVO" "$USER"

    # Eliminar enlaces simbólicos antiguos de grupos
    for G in Reprobados Recursadores; do
        if [ -L "$BASE/usuarios/$USER/$G" ]; then
            sudo rm -f "$BASE/usuarios/$USER/$G"
        fi
    done

    # Crear nuevo enlace simbólico al grupo actual
    sudo ln -s /srv/ftp/grupos/$NUEVO $BASE/usuarios/$USER/$NUEVO

    # Asegurar permisos correctos sobre el enlace
    sudo chown -h $USER:$NUEVO $BASE/usuarios/$USER/$NUEVO

    echo "================================="
    echo "Grupo actualizado correctamente."
    echo "Usuario $USER ahora pertenece a $NUEVO"
    echo "================================="
}
