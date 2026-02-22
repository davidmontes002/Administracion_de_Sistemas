Configurar_SSH() {

    echo "================================="
    echo "     CONFIGURACION SSH"
    echo "================================="

    # Verificar que DHCP esté activo
    if ! systemctl is-active --quiet isc-dhcp-server; then
        echo "ERROR: DHCP no esta activo."
        echo "Configure primero el DHCP."
        read -p "Presione Enter para continuar..."
        return
    fi

    # Obtener IP interna automáticamente
    IP_INTERNA=$(hostname -I | awk '{print $1}')

    if [ -z "$IP_INTERNA" ]; then
        echo "No se pudo detectar la IP interna."
        read -p "Presione Enter para continuar..."
        return
    fi

    echo "IP detectada: $IP_INTERNA"

    # Respaldar configuración
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak

    # Configurar para escuchar solo en la IP interna
    sudo sed -i "s/^#ListenAddress.*/ListenAddress $IP_INTERNA/" /etc/ssh/sshd_config

    # Reiniciar servicio
    sudo systemctl restart ssh

    echo "SSH configurado para escuchar en $IP_INTERNA"
    read -p "Presione Enter para continuar..."
}