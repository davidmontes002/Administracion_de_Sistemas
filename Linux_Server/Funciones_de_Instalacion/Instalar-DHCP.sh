Instalar_Silencioso() {
    echo
    echo "=== INSTALACION SILENCIOSA DHCP ==="

    if dpkg -l | grep -q "^ii  isc-dhcp-server "; then
        echo "[+] DHCP ya esta instalado."
    else
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y isc-dhcp-server >/dev/null 2>&1
        echo "[+] Instalación completada."
    fi
    echo
    read -p "Presiona Enter para regresar al menu..."
}