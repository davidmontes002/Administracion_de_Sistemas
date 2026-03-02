#!/bin/bash

CONF="/etc/vsftpd.conf"
PUBLIC_DIR="/srv/ftp/Public"   # Nota: mayúscula para coherencia con usuarios

Usuario_Anonimo() {

    # Verificar que vsftpd esté instalado
    if ! dpkg -l | grep -q vsftpd; then
        echo "vsftpd no está instalado."
        return
    fi

    # Crear carpeta pública si no existe
    sudo mkdir -p "$PUBLIC_DIR"

    # Backup de configuración si no existe
    if [ ! -f "${CONF}.backup" ]; then
        sudo cp "$CONF" "${CONF}.backup"
    fi

    # Verificar si la configuración anónima ya existe
    if grep -q "^anonymous_enable=YES" "$CONF"; then
        echo "Usuario anónimo ya está configurado."
        return
    fi

    # Eliminar configuraciones previas relacionadas
    sudo sed -i '/^anonymous_enable/d' "$CONF"
    sudo sed -i '/^anon_root/d' "$CONF"
    sudo sed -i '/^anon_upload_enable/d' "$CONF"
    sudo sed -i '/^anon_mkdir_write_enable/d' "$CONF"
    sudo sed -i '/^anon_other_write_enable/d' "$CONF"

    # Agregar configuración anónima
    sudo bash -c "cat >> $CONF <<EOF

# CONFIGURACION USUARIO ANONIMO
anonymous_enable=YES
anon_root=$PUBLIC_DIR
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO
EOF"

    # Reiniciar servicio
    sudo systemctl restart vsftpd

    echo
    echo "Usuario anónimo configurado correctamente."
    echo "Solo tiene acceso de lectura a: $PUBLIC_DIR"
}
