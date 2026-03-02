Instalar_SSH() {

    echo "================================="
    echo "     INSTALACION SSH"
    echo "================================="

    if dpkg -l | grep -q openssh-server; then
        echo "OpenSSH ya esta instalado."
    else
        echo "Instalando OpenSSH..."
        sudo apt update -qq 
        sudo apt install -y openssh-server 
        echo "Instalacion completada."
    fi

    sudo systemctl enable ssh > /dev/null 2>&1 || sudo systemctl enable sshd > /dev/null 2>&1
    sudo systemctl start ssh || sudo systemctl start sshd

    read -p "Presione Enter para continuar..."
}
