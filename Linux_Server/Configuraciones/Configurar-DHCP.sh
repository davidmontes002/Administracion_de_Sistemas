function Configurar_DHCP() {

    echo
    echo "=============================="
    echo "   [SECCION 1] Verificando DHCP"
    echo "=============================="

    if ! dpkg -l | grep -q isc-dhcp-server; then
        echo "[+] Instalando DHCP Server..."
        sudo apt update -y >/dev/null 2>&1
        sudo apt install isc-dhcp-server -y >/dev/null 2>&1
        echo "[+] DHCP Server instalado correctamente."
    else
        echo "[-] DHCP Server ya esta instalado."
    fi

    echo
    echo "=============================="
    echo "   [SECCION 2] Configuracion IP Fija"
    echo "=============================="

    echo "Interfaces disponibles:"
    ip -o link show | awk -F': ' '{print $2}'

    read -p "Nombre de la interfaz de red interna (ej: enp0s8): " IFACE

    read -p "IP del servidor DHCP (ej: 192.168.100.1): " IP_SERVER
    while ! validar_ip $IP_SERVER; do
        echo "Error: IP no valida."
        read -p "Ingresa IP valida: " IP_SERVER
    done

    read -p "Prefijo de red (ej: 24): " PREFIX
    while ! [[ $PREFIX =~ ^[0-9]+$ ]] || (( PREFIX < 8 || PREFIX > 32 )); do
        echo "Error: Prefijo invalido (8-32)"
        read -p "Ingresa prefijo valido: " PREFIX
    done

    NETPLAN_FILE="/etc/netplan/00-dhcp-interno.yaml"

    sudo tee $NETPLAN_FILE >/dev/null <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: no
      addresses: [$IP_SERVER/$PREFIX]
EOF

    sudo netplan apply
    sudo sed -i "s/^INTERFACESv4=.*/INTERFACESv4=\"$IFACE\"/" /etc/default/isc-dhcp-server

    echo
    echo "=============================="
    echo "   [SECCION 3] Configuración del Scope DHCP"
    echo "=============================="

    read -p "Nombre del Scope: " SCOPE_NAME

    # IP Inicial
    while true; do
        read -p "IP inicial del rango DHCP: " START_IP
        if ! validar_ip $START_IP; then
            echo "Error: IP invalida"
        elif es_broadcast_o_red $START_IP; then
            echo "Error: IP no puede ser .0 o .255"
        else
            break
        fi
    done

    # IP Final
    while true; do
        read -p "IP final del rango DHCP: " END_IP
        if ! validar_ip $END_IP; then
            echo "Error: IP invalida"
        elif (( $(ip_a_num $END_IP) <= $(ip_a_num $START_IP) )); then
            echo "Error: IP final debe ser mayor que la inicial"
        elif es_broadcast_o_red $END_IP; then
            echo "Error: IP no puede ser .0 o .255"
        else
            break
        fi
    done

    # Gateway (opcional)
    read -p "Gateway (opcional, Enter para omitir): " GW
    if [[ -n "$GW" ]]; then
        while ! validar_ip $GW; do
            echo "Error: IP invalida"
            read -p "Ingresa IP Gateway valida o Enter para omitir: " GW
            [[ -z "$GW" ]] && break
        done
    fi

# DNS (opcional)
read -p "DNS (opcional, Enter para usar IP del servidor): " DNS

if [[ -z "$DNS" ]]; then
    DNS="$IP_SERVER"
    echo "[+] No se ingreso DNS. Se usará la IP del servidor como DNS: $DNS"
else
    while ! validar_ip $DNS; do
        echo "Error: IP invalida"
        read -p "Ingresa IP DNS valida o Enter para usar IP del servidor: " DNS
        if [[ -z "$DNS" ]]; then
            DNS="$IP_SERVER"
            echo "[+] No se ingresó DNS. Se usara la IP del servidor como DNS: $DNS"
            break
        fi
    done
fi

    # Tiempo de concesion
    read -p "Tiempo de concesion (en minutos): " LEASE
    while ! [[ $LEASE =~ ^[0-9]+$ ]] || (( LEASE <= 0 )); do
        echo "Error: Ingresa un numero valido"
        read -p "Tiempo de concesion (en minutos): " LEASE
    done

    # Crear dhcpd.conf con el nuevo formato
    NET="${START_IP%.*}"
    RANGO_INI="$START_IP"
    IP_FIN="$END_IP"

    cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf > /dev/null
subnet $NET.0 netmask 255.255.255.0 {
  range $RANGO_INI $IP_FIN;
  option subnet-mask 255.255.255.0;
  ${GW:+option routers $GW;}
  ${DNS:+option domain-name-servers $DNS;}
  default-lease-time $((LEASE*60));
  max-lease-time $((LEASE*60));
}
EOF

    echo "Configuracion completada."
    read -p "Presiona Enter para regresar al menu..."
}
