#==============================
# Crear Dominio
#==============================
Crear_Dominio() {

    echo "===== CREAR NUEVO DOMINIO ====="

    read -p "Nombre del dominio: " DOMINIO

    if [[ -z "$DOMINIO" ]]; then
        echo "El nombre del dominio no puede estar vacio."
        return
    fi

    read -p "IP para el dominio (ENTER para usar IP del servidor): " IP_DOM

    if [[ -z "$IP_DOM" ]]; then
        IP_DOM="$IP_SERVER"
    fi

    ZONA="/etc/bind/db.$DOMINIO"

    # Crear archivo de zona
    sudo tee $ZONA > /dev/null <<EOF
\$TTL 604800
@   IN  SOA $DOMINIO. admin.$DOMINIO. (
        2         ; Serial
        604800    ; Refresh
        86400     ; Retry
        2419200   ; Expire
        604800 )  ; Negative Cache TTL

@       IN  NS      $DOMINIO.
@       IN  A       $IP_DOM
www     IN  A       $IP_DOM
ftp     IN  CNAME   www
EOF

    # Agregar zona a named.conf.local
    sudo tee -a /etc/bind/named.conf.local > /dev/null <<EOF

zone "$DOMINIO" {
    type master;
    file "/etc/bind/db.$DOMINIO";
};
EOF

    sudo systemctl restart bind9

    echo "Dominio $DOMINIO creado correctamente."
}

#===============================
# Eiminar domino
#===============================
Eliminar_Dominio() {

    echo "===== ELIMINAR DOMINIO ====="

    read -p "Nombre del dominio a eliminar: " DOMINIO

    if [[ -z "$DOMINIO" ]]; then
        echo "Debe ingresar un dominio."
        return
    fi

    # Eliminar archivo de zona
    sudo rm -f /etc/bind/db.$DOMINIO

    # Eliminar bloque de named.conf.local
    sudo sed -i "/zone \"$DOMINIO\" {/,/};/d" /etc/bind/named.conf.local

    sudo systemctl restart bind9

    echo "Dominio $DOMINIO eliminado correctamente."
}