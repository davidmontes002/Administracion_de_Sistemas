#!/bin/bash

function Validar_Puerto_HTTP() {
    local puerto=$1
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ "$puerto" -lt 1 ] || [ "$puerto" -gt 65535 ]; then return 1; fi
    if ss -tulpn 2>/dev/null | grep -q ":$puerto "; then return 2; fi
    return 0
}

function Descarga_FTP_Segura() {
    local ruta_remota=$1
    local dest_bin="/tmp/paquete.deb"
    
    echo "==================================================="
    echo "  DESCARGA SEGURA DESDE FTP PRIVADO"
    echo "==================================================="
    read -p "IP del FTP (ej. 127.0.0.1): " IP_FTP
    read -p "Usuario FTP (ej. repo): " USR_FTP
    read -s -p "Contraseña: " PASS_FTP
    echo ""

    # Limpiamos basura de intentos anteriores
    rm -f "$dest_bin" "$dest_bin.sha256"

    echo "> 1. Descargando binario y hash (Túnel FTPS)..."
    # Añadimos -k y --ssl-reqd para forzar la conexión segura
    curl -s -k --ssl-reqd --user "$USR_FTP:$PASS_FTP" "ftp://$IP_FTP/http/Linux/$ruta_remota" -o "$dest_bin"
    curl -s -k --ssl-reqd --user "$USR_FTP:$PASS_FTP" "ftp://$IP_FTP/http/Linux/$ruta_remota.sha256" -o "$dest_bin.sha256"

    echo "> 2. Verificando integridad SHA256..."
    
    # Seguro anti-falsos positivos: Revisamos si los archivos existen y no están vacíos (-s)
    if [ ! -s "$dest_bin" ] || [ ! -s "$dest_bin.sha256" ]; then
        echo "[-] ERROR: Descarga fallida. El FTP blindado bloqueó la conexión o el archivo no existe."
        return 1
    fi

    local hash_remoto=$(cat "$dest_bin.sha256")
    local hash_local=$(sha256sum "$dest_bin" | awk '{print $1}')

    if [ "$hash_remoto" == "$hash_local" ] && [ -n "$hash_remoto" ]; then
        echo "[+] INTEGRIDAD CONFIRMADA."
        # Instalación silenciosa
        sudo dpkg -i "$dest_bin" >/dev/null 2>&1
        sudo apt-get install -f -y -qq >/dev/null 2>&1
        return 0
    else
        echo "[-] ARCHIVO CORRUPTO. Los Hashes no coinciden."
        return 1
    fi
}

function Desplegar_Apache2() {
    echo "====================================="
    echo "    DESPLIEGUE HÍBRIDO: APACHE2"
    echo "====================================="
    read -p "Instalar desde: 1) Internet  2) FTP Privado: " ORIGEN
    read -p "¿Activar SSL? [S/N]: " USAR_SSL

    while true; do
        read -p "Ingrese puerto base (ej. 80): " PUERTO
        Validar_Puerto_HTTP "$PUERTO"
        estado=$?
        if [ $estado -eq 0 ]; then break; elif [ $estado -eq 2 ]; then echo "[-] Puerto ocupado."; fi
    done

    if [ "$ORIGEN" == "1" ]; then
        sudo apt-get update -qq && sudo apt-get install -y apache2 >/dev/null
    else
        Descarga_FTP_Segura "Apache/apache2_*.deb" || return
    fi

    sudo sed -i -E "s/Listen [0-9]+/Listen $PUERTO/g" /etc/apache2/ports.conf
    sudo sed -i -E "s/<VirtualHost \*:[0-9]+>/<VirtualHost \*:$PUERTO>/g" /etc/apache2/sites-available/000-default.conf
    
    sudo bash -c "cat > /var/www/html/index.html <<EOF
<h1>Servidor Apache2 Orquestado</h1><h3>Puerto: $PUERTO</h3>
EOF"

    if [[ "${USAR_SSL,,}" == "s" ]]; then
        Activar_SSL_Apache "$PUERTO"
    else
        sudo systemctl restart apache2
    fi
    echo "[+] Despliegue Apache finalizado."
    read -p "Presione Enter..."
}

function Desplegar_Nginx() {
    echo "====================================="
    echo "    DESPLIEGUE HÍBRIDO: NGINX"
    echo "====================================="
    read -p "Instalar desde: 1) Internet  2) FTP Privado: " ORIGEN
    read -p "¿Activar SSL? [S/N]: " USAR_SSL

    while true; do
        read -p "Ingrese puerto base (ej. 80): " PUERTO
        Validar_Puerto_HTTP "$PUERTO"
        if [ $? -eq 0 ]; then break; fi
    done

    if [ "$ORIGEN" == "1" ]; then
        sudo apt-get update -qq && sudo apt-get install -y nginx >/dev/null
    else
        Descarga_FTP_Segura "Nginx/nginx_*.deb" || return
    fi

    sudo systemctl stop nginx >/dev/null 2>&1
    sudo mkdir -p /var/www/nginx
    sudo bash -c "cat > /var/www/nginx/index.html <<EOF
<h1>Servidor Nginx Orquestado</h1><h3>Puerto: $PUERTO</h3>
EOF"

    if [[ "${USAR_SSL,,}" == "s" ]]; then
        Activar_SSL_Nginx "$PUERTO"
    else
        sudo sed -i -E "s/listen [0-9]+ default_server;/listen $PUERTO default_server;/g" /etc/nginx/sites-available/default
        sudo sed -i 's|root /var/www/html;|root /var/www/nginx;|g' /etc/nginx/sites-available/default
        sudo systemctl restart nginx
    fi
    echo "[+] Despliegue Nginx finalizado."
    read -p "Presione Enter..."
}

function Desplegar_Tomcat() {
    echo "====================================="
    echo "    DESPLIEGUE HÍBRIDO: TOMCAT"
    echo "====================================="
    read -p "¿Activar SSL? [S/N]: " USAR_SSL
    read -p "Ingrese el puerto HTTP (ej. 8080): " PUERTO

    sudo apt-get install -y default-jdk >/dev/null 2>&1
    if ! id "tomcat" &>/dev/null; then sudo useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat; fi
    
    sudo rm -rf /opt/tomcat/*
    wget -q "https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.83/bin/apache-tomcat-9.0.83.tar.gz" -O /tmp/tomcat.tar.gz
    sudo tar -xf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1
    
    sudo chown -R tomcat:tomcat /opt/tomcat
    sudo sed -i -E "s/port=\"[0-9]+\" protocol=\"HTTP\/1.1\"/port=\"$PUERTO\" protocol=\"HTTP\/1.1\"/g" /opt/tomcat/conf/server.xml

    JAVA_PATH=$(readlink -f /usr/bin/java | sed "s:bin/java::")
    sudo bash -c "cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat
After=network.target
[Service]
Type=forking
User=tomcat
Group=tomcat
Environment=JAVA_HOME=$JAVA_PATH
Environment=CATALINA_PID=/opt/tomcat/temp/tomcat.pid
Environment=CATALINA_HOME=/opt/tomcat
Environment=CATALINA_BASE=/opt/tomcat
ExecStart=/opt/tomcat/bin/startup.sh
ExecStop=/opt/tomcat/bin/shutdown.sh
[Install]
WantedBy=multi-user.target
EOF"

    sudo mkdir -p /opt/tomcat/webapps/ROOT
    sudo bash -c "cat > /opt/tomcat/webapps/ROOT/index.jsp <<EOF
<h1>Tomcat Orquestado</h1>
EOF"
    sudo chown tomcat:tomcat /opt/tomcat/webapps/ROOT/index.jsp

    sudo systemctl daemon-reload
    sudo systemctl enable tomcat >/dev/null 2>&1
    sudo systemctl start tomcat

    if [[ "${USAR_SSL,,}" == "s" ]]; then
        Activar_SSL_Tomcat
    fi
    
    echo "[+] Despliegue Tomcat finalizado."
    read -p "Presione Enter..."
}