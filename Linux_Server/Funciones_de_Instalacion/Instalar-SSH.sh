Instalar_SSH() {

    echo "================================="
    echo "     INSTALACION SSH"
    echo "================================="

    if dpkg -l | grep -q openssh-server; then
        echo "OpenSSH ya esta instalado."
    else
        echo "Instalando OpenSSH..."
        sudo apt update -qq > /dev/null 2>&1
        sudo apt install -y openssh-server > /dev/null 2>&1
        echo "Instalacion completada."
    fi

    sudo systemctl enable ssh > /dev/null 2>&1
    sudo systemctl start ssh

    read -p "Presione Enter para continuar..."
}