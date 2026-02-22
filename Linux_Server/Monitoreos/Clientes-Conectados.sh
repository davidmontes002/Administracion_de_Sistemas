# ==============================
# Monitoreo de clientes
# ==============================
function Monitorear_Clientes() {
    echo
    echo "=== CLIENTES DHCP CONECTADOS (LINUX) ==="
    echo

    if [[ ! -f /var/lib/dhcp/dhcpd.leases ]]; then
        echo "No hay clientes conectados o archivo de leases no existe."
    else
        sudo awk '/lease/ {ip=$2} /hardware ethernet/ {mac=$3} /client-hostname/ {host=$2} /ends/ {print "IP: " ip ", MAC: " mac ", Host: " host}' /var/lib/dhcp/dhcpd.leases
    fi

    echo
    read -p "Presiona Enter para regresar al menu..."
}