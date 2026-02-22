# ==============================
# Iniciar / Reiniciar DHCP
# ==============================
function Iniciar_DHCP() {
    echo
    echo "=== INICIANDO / REINICIANDO SERVICIO DHCP ==="
    sudo systemctl enable isc-dhcp-server
    sudo systemctl restart isc-dhcp-server
    sudo systemctl status isc-dhcp-server --no-pager
    echo
    read -p "Presiona Enter para regresar al menu..."
}
