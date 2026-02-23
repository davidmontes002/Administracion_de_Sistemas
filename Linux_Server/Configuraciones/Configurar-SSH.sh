Configurar_SSH() {

    echo "================================="
    echo "     CONFIGURACION SSH"
    echo "================================="

    # Verificar que el servicio SSH exista
    if ! systemctl list-unit-files | grep -q ssh; then
        echo "ERROR: OpenSSH no esta instalado."
        read -p "Presione Enter para continuar..."
        return
    fi

    # Eliminar cualquier ListenAddress para que escuche en todas las interfaces
    sudo sed -i '/^ListenAddress/d' /etc/ssh/sshd_config

    # Asegurar que no haya restricciones innecesarias
    sudo sed -i 's/^#Port 22/Port 22/' /etc/ssh/sshd_config

    # Validar configuración antes de reiniciar
    if ! sudo sshd -t; then
        echo "ERROR en la configuracion de SSH."
        read -p "Presione Enter para continuar..."
        return
    fi

    # Habilitar servicio al inicio
    sudo systemctl enable ssh

    # Reiniciar servicio forzado
    sudo systemctl restart ssh

    # Mostrar estado
    systemctl status ssh --no-pager

    echo "SSH configurado correctamente."
    echo "Escuchando en todas las interfaces (0.0.0.0)."
    read -p "Presione Enter para continuar..."
}