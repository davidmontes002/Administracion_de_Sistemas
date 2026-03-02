#!/bin/bash

BASE="/srv/ftp"

Registrar_Alumno() {

    read -p "Nombre de usuario: " USER
    read -s -p "Contraseña: " PASS
    echo
    read -p "Grupo (Reprobados/Recursadores): " GRUPO

    # Validar que el grupo exista
    if ! getent group "$GRUPO" > /dev/null; then
        echo "El grupo $GRUPO no existe. Primero crea el grupo."
        return
    fi

    # Validar si el usuario ya existe
    if id "$USER" &>/dev/null; then
        echo "El usuario ya existe."
        return
    fi

    # Crear usuario sin shell de login
    sudo useradd -m -d $BASE/usuarios/$USER -s /usr/sbin/nologin -G $GRUPO $USER
    echo "$USER:$PASS" | sudo chpasswd

    # Crear carpeta personal y de grupo
    sudo mkdir -p $BASE/usuarios/$USER/$USER
    sudo ln -s /srv/ftp/grupos/$GRUPO $BASE/usuarios/$USER/$GRUPO

    # Eliminar carpeta public anterior si existe
    sudo umount $BASE/usuarios/$USER/Public 2>/dev/null
    sudo rm -rf $BASE/usuarios/$USER/Public
    sudo mkdir -p $BASE/usuarios/$USER/Public

    # Bind mount de la carpeta global public
    sudo mount --bind /srv/ftp/Public $BASE/usuarios/$USER/Public

    # Asignar permisos
    sudo chown -R $USER:$GRUPO $BASE/usuarios/$USER/$USER
    sudo chown -R $USER:$GRUPO $BASE/usuarios/$USER/$GRUPO
    sudo chmod -R 770 $BASE/usuarios/$USER/$USER
    sudo chmod 770 $BASE/usuarios/$USER/$GRUPO

    echo "Usuario creado correctamente."
    echo "Estructura del usuario:"
    echo "Public   → carpeta pública (bind mount, lectura para todos)"
    echo "$GRUPO   → carpeta de grupo"
    echo "$USER    → carpeta personal"
}
