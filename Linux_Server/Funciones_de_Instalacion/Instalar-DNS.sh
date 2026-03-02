Instalar_DNS() {
    echo
    echo "=== INSTALACION SILENCIOSA DNS (BIND9) ==="

    sudo mkdir -p /etc/bind

    if dpkg -l | grep -q "^ii  bind9 "; then
        echo "[+] DNS ya esta instalado."
    else
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y bind9 >/dev/null 2>&1
        sudo systemctl enable bind9 >/dev/null 2>&1
        sudo systemctl start bind9 >/dev/null 2>&1
        echo "[+] DNS instalado correctamente."
    fi
    echo
    read -p "Presiona Enter para regresar al menu..."
}
