#!/bin/bash

Instalar_FTP() {

    echo "================================="
    echo "     INSTALACION SERVIDOR FTP"
    echo "================================="

    # Verificar si ya está instalado
    if dpkg -l | grep -q "^ii  vsftpd"; then
        echo "vsftpd ya está instalado."

        if systemctl is-active --quiet vsftpd; then
            echo "El servicio FTP ya está en ejecución."
        else
            echo "El servicio está instalado pero detenido. Iniciando..."
            sudo systemctl start vsftpd
        fi

        return
    fi

    echo "Instalando vsftpd..."
    sudo apt update -y
    sudo apt install vsftpd -y

    sudo systemctl enable vsftpd
    sudo systemctl stop vsftpd

    # Agregar nologin si no existe
    if ! grep -q "/usr/sbin/nologin" /etc/shells; then
        echo "/usr/sbin/nologin" | sudo tee -a /etc/shells
    fi

    # Crear estructura base
    sudo mkdir -p /srv/ftp/Public
    sudo mkdir -p /srv/ftp/grupos
    sudo mkdir -p /srv/ftp/usuarios

    # Crear grupo general ftpusers
    sudo groupadd -f ftp_public
    sudo chown root:ftp_public /srv/ftp/Public
    sudo chmod 2775 /srv/ftp/Public

    # Configuración personalizada
    sudo bash -c 'cat > /etc/vsftpd.conf <<EOF
listen=YES

# ANONIMO SOLO LECTURA
anonymous_enable=YES
anon_world_readable_only=YES
anon_upload_enable=NO
anon_mkdir_write_enable=NO
anon_other_write_enable=NO

# USUARIOS LOCALES
local_enable=YES
write_enable=YES
chroot_local_user=YES
allow_writeable_chroot=YES

# Cada usuario entra a su carpeta
local_root=/srv/ftp/usuarios/\$USER

pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40100
EOF'

    sudo systemctl start vsftpd

    echo "================================="
    echo "FTP instalado y configurado correctamente."
    echo "================================="
}
