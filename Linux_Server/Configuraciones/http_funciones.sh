#!/bin/bash

# ==============================================================
# FUNCIONES AUXILIARES: VALIDACIÓN Y BÚSQUEDA DE VERSIONES
# ==============================================================

function Validar_Puerto_HTTP() {
    local puerto=$1
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [ "$puerto" -lt 1 ] || [ "$puerto" -gt 65535 ]; then
        return 1
    fi
    if ss -tulpn 2>/dev/null | grep -q ":$puerto "; then
        return 2
    fi
    return 0
}

function Seleccionar_Version() {
    local paquete=$1
    echo "[*] Consultando repositorios para $paquete..."
    versiones=$(apt-cache madison "$paquete" | awk '{print $3}' | head -n 3)
    
    if [ -z "$versiones" ]; then
        echo "[-] Error: No se encontraron versiones para $paquete."
        VERSION_ELEGIDA=""
        return 1
    fi
    
    mapfile -t arr_versiones <<< "$versiones"
    echo "Versiones disponibles para $paquete:"
    for i in "${!arr_versiones[@]}"; do
        echo "  $((i+1))) ${arr_versiones[$i]}"
    done
    
    read -p "Seleccione el número de la versión deseada: " sel_ver
    
    if [[ "$sel_ver" =~ ^[0-9]+$ ]] && [ "$sel_ver" -ge 1 ] && [ "$sel_ver" -le "${#arr_versiones[@]}" ]; then
        VERSION_ELEGIDA="${arr_versiones[$((sel_ver-1))]}"
        echo "[+] Versión seleccionada: $VERSION_ELEGIDA"
    else
        echo "[-] Selección inválida."
        VERSION_ELEGIDA=""
    fi
}

# ==============================================================
# INSTALACIÓN Y CONFIGURACIÓN DE APACHE2
# ==============================================================

function Desplegar_Apache2() {
    echo "====================================="
    echo "    DESPLIEGUE DINÁMICO: APACHE2"
    echo "====================================="

    Seleccionar_Version "apache2"
    if [ -z "$VERSION_ELEGIDA" ]; then
        read -p "Presione Enter para volver..."
        return
    fi

    while true; do
        read -p "Ingrese el puerto de escucha (ej. 80, 8080): " PUERTO
        Validar_Puerto_HTTP "$PUERTO"
        estado=$?
        if [ $estado -eq 0 ]; then break;
        elif [ $estado -eq 1 ]; then echo "[-] Error: Puerto inválido.";
        elif [ $estado -eq 2 ]; then echo "[-] Error: Puerto ocupado."; fi
    done

    echo "[*] Actualizando lista de paquetes..."
    sudo apt-get update -qq
    echo "[*] Intentando instalar Apache2 versión $VERSION_ELEGIDA..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades apache2="$VERSION_ELEGIDA"

    if [ ! -d "/etc/apache2" ]; then
        echo "[-] ERROR CRÍTICO: La instalación de Apache falló."
        read -p "Presione Enter para volver al menú..."
        return
    fi

    echo "[*] Configurando el puerto $PUERTO..."
    # Se usa regex [0-9]+ para atrapar cualquier puerto previo
    sudo sed -i -E "s/Listen [0-9]+/Listen $PUERTO/g" /etc/apache2/ports.conf
    sudo sed -i -E "s/<VirtualHost \*:[0-9]+>/<VirtualHost \*:$PUERTO>/g" /etc/apache2/sites-available/000-default.conf

    echo "[*] Aplicando Hardening (Seguridad)..."
    sudo sed -i "s/ServerTokens OS/ServerTokens Prod/g" /etc/apache2/conf-available/security.conf
    sudo sed -i "s/ServerSignature On/ServerSignature Off/g" /etc/apache2/conf-available/security.conf
    
    sudo a2enmod headers >/dev/null 2>&1
    
    # Limpiar reglas anteriores si el script se corre múltiples veces
    sudo sed -i '/Header always set X-Frame-Options/d' /etc/apache2/apache2.conf
    sudo sed -i '/Header always set X-Content-Type-Options/d' /etc/apache2/apache2.conf
    sudo sed -i '/TraceEnable off/d' /etc/apache2/apache2.conf
    
    sudo bash -c 'cat >> /etc/apache2/apache2.conf <<EOF
Header always set X-Frame-Options "SAMEORIGIN"
Header always set X-Content-Type-Options "nosniff"
TraceEnable off
EOF'

    echo "[*] Generando página personalizada..."
    sudo bash -c "cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Despliegue Apache2</title></head>
<body>
    <h1>Servidor: Apache2</h1>
    <h2>Version Elegida: $VERSION_ELEGIDA</h2>
    <h3>Puerto de Escucha: $PUERTO</h3>
</body>
</html>
EOF"

    echo "[*] Configurando Firewall..."
    sudo ufw allow "$PUERTO"/tcp >/dev/null 2>&1
    if [ "$PUERTO" != "80" ]; then
        sudo ufw delete allow 80/tcp >/dev/null 2>&1
    fi

    echo "[*] Reiniciando servicio Apache2..."
    sudo systemctl restart apache2

    echo "====================================="
    echo "[+] Despliegue finalizado."
    echo "====================================="
    read -p "Presione Enter para volver al menú..."
}

# ==============================================================
# INSTALACIÓN Y CONFIGURACIÓN DE NGINX
# ==============================================================

function Desplegar_Nginx() {
    echo "====================================="
    echo "    DESPLIEGUE DINÁMICO: NGINX"
    echo "====================================="

    Seleccionar_Version "nginx"
    if [ -z "$VERSION_ELEGIDA" ]; then
        read -p "Presione Enter para volver..."
        return
    fi

    while true; do
        read -p "Ingrese el puerto de escucha (ej. 80, 8080): " PUERTO
        Validar_Puerto_HTTP "$PUERTO"
        estado=$?
        if [ $estado -eq 0 ]; then break;
        elif [ $estado -eq 1 ]; then echo "[-] Error: Puerto inválido.";
        elif [ $estado -eq 2 ]; then echo "[-] Error: Puerto ocupado."; fi
    done

    echo "[*] Actualizando lista de paquetes..."
    sudo apt-get update -qq
    echo "[*] Instalando Nginx versión $VERSION_ELEGIDA..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --allow-downgrades nginx="$VERSION_ELEGIDA"

    if [ ! -d "/etc/nginx" ]; then
        echo "[-] ERROR CRÍTICO: La instalación falló."
        read -p "Presione Enter para volver al menú..."
        return
    fi

    # Detenemos Nginx temporalmente por si chocó con Apache al instalarse
    sudo systemctl stop nginx >/dev/null 2>&1

    echo "[*] Separando directorio web de Nginx..."
    sudo mkdir -p /var/www/nginx
    sudo sed -i 's|root /var/www/html;|root /var/www/nginx;|g' /etc/nginx/sites-available/default

    echo "[*] Configurando el puerto $PUERTO..."
    sudo sed -i -E "s/listen [0-9]+ default_server;/listen $PUERTO default_server;/g" /etc/nginx/sites-available/default
    sudo sed -i -E "s/listen \[::\]:[0-9]+ default_server;/listen \[::\]:$PUERTO default_server;/g" /etc/nginx/sites-available/default

    echo "[*] Aplicando Hardening (Seguridad)..."
    sudo sed -i 's/# server_tokens off;/server_tokens off;/g' /etc/nginx/nginx.conf
    
    # Limpiamos cabeceras anteriores por si se corre más de una vez
    sudo sed -i '/add_header X-Frame-Options/d' /etc/nginx/sites-available/default
    sudo sed -i '/add_header X-Content-Type-Options/d' /etc/nginx/sites-available/default
    sudo sed -i "/server_name _;/a \ \tadd_header X-Frame-Options SAMEORIGIN;\n\tadd_header X-Content-Type-Options nosniff;" /etc/nginx/sites-available/default

    echo "[*] Generando página personalizada..."
    # Ahora lo guardamos en /var/www/nginx/
    sudo bash -c "cat > /var/www/nginx/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>Despliegue Nginx</title></head>
<body>
    <h1>Servidor: Nginx</h1>
    <h2>Version Elegida: $VERSION_ELEGIDA</h2>
    <h3>Puerto de Escucha: $PUERTO</h3>
</body>
</html>
EOF"

    echo "[*] Configurando Firewall..."
    sudo ufw allow "$PUERTO"/tcp >/dev/null 2>&1
    if [ "$PUERTO" != "80" ]; then
        sudo ufw delete allow 80/tcp >/dev/null 2>&1
    fi

    echo "[*] Reiniciando servicio Nginx..."
    sudo systemctl restart nginx

    echo "====================================="
    echo "[+] Despliegue finalizado."
    echo "====================================="
    read -p "Presione Enter para volver al menú..."
}

# ==============================================================
# INSTALACIÓN Y CONFIGURACIÓN DE TOMCAT
# ==============================================================

function Desplegar_Tomcat() {
    echo "====================================="
    echo "    DESPLIEGUE DINÁMICO: TOMCAT"
    echo "====================================="

    echo "Seleccione la versión de Tomcat a instalar:"
    echo "  1) Tomcat 9.0.83 (Estable / LTS)"
    echo "  2) Tomcat 10.1.16 (Desarrollo / Latest)"
    read -p "Opción: " t_opcion
    
    if [ "$t_opcion" == "1" ]; then
        TOMCAT_VER="9.0.83"
        TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.83/bin/apache-tomcat-9.0.83.tar.gz"
    elif [ "$t_opcion" == "2" ]; then
        TOMCAT_VER="10.1.16"
        TOMCAT_URL="https://archive.apache.org/dist/tomcat/tomcat-10/v10.1.16/bin/apache-tomcat-10.1.16.tar.gz"
    else
        echo "[-] Opción inválida."
        read -p "Presione Enter para volver..."
        return
    fi

    while true; do
        read -p "Ingrese el puerto de escucha (ej. 8080, 8888): " PUERTO
        Validar_Puerto_HTTP "$PUERTO"
        estado=$?
        if [ $estado -eq 0 ]; then break;
        elif [ $estado -eq 1 ]; then echo "[-] Error: Puerto inválido.";
        elif [ $estado -eq 2 ]; then echo "[-] Error: Puerto ocupado."; fi
    done

    echo "[*] Instalando dependencias de Java (JDK)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y default-jdk >/dev/null 2>&1

    echo "[*] Creando usuario dedicado 'tomcat'..."
    if ! id "tomcat" &>/dev/null; then
        sudo useradd -r -m -U -d /opt/tomcat -s /bin/false tomcat
    fi

    echo "[*] Descargando y extrayendo binarios de Tomcat $TOMCAT_VER..."
    wget -q $TOMCAT_URL -O /tmp/tomcat.tar.gz
    sudo mkdir -p /opt/tomcat
    
    # Limpiamos instalaciones previas y extraemos los binarios correctamente
    sudo rm -rf /opt/tomcat/*
    sudo tar -xf /tmp/tomcat.tar.gz -C /opt/tomcat --strip-components=1
    sudo rm /tmp/tomcat.tar.gz

    echo "[*] Aplicando políticas de Mínimo Privilegio (Chmod/Chown)..."
    sudo chown -R tomcat:tomcat /opt/tomcat
    sudo chmod -R 750 /opt/tomcat

    echo "[*] Configurando el puerto $PUERTO..."
    # Cambiamos SOLO el puerto del conector HTTP web, protegiendo los puertos internos
    sudo sed -i -E "s/port=\"[0-9]+\" protocol=\"HTTP\/1.1\"/port=\"$PUERTO\" protocol=\"HTTP\/1.1\"/g" /opt/tomcat/conf/server.xml

    echo "[*] Aplicando Hardening (Ocultar versión)..."
    sudo sed -i "s/connectionTimeout=\"20000\"/connectionTimeout=\"20000\" server=\"Prod\"/g" /opt/tomcat/conf/server.xml

    echo "[*] Configurando variables de entorno y servicio daemon..."
    JAVA_PATH=$(readlink -f /usr/bin/java | sed "s:bin/java::")
    
    sudo bash -c "cat > /etc/systemd/system/tomcat.service <<EOF
[Unit]
Description=Apache Tomcat Web Application Container
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

    echo "[*] Generando página JSP personalizada..."
    sudo mkdir -p /opt/tomcat/webapps/ROOT
    sudo bash -c "cat > /opt/tomcat/webapps/ROOT/index.jsp <<EOF
<%@ page language=\"java\" contentType=\"text/html; charset=UTF-8\" pageEncoding=\"UTF-8\"%>
<!DOCTYPE html>
<html>
<head><title>Despliegue Tomcat</title></head>
<body>
    <h1>Servidor: Tomcat (Entorno Java)</h1>
    <h2>Version Elegida: $TOMCAT_VER</h2>
    <h3>Puerto de Escucha: $PUERTO</h3>
</body>
</html>
EOF"
    sudo chown tomcat:tomcat /opt/tomcat/webapps/ROOT/index.jsp

    echo "[*] Configurando Firewall..."
    sudo ufw allow "$PUERTO"/tcp >/dev/null 2>&1

    echo "[*] Iniciando Tomcat..."
    sudo systemctl daemon-reload
    sudo systemctl enable tomcat >/dev/null 2>&1
    sudo systemctl restart tomcat

    echo "====================================="
    echo "[+] Despliegue finalizado."
    echo "====================================="
    read -p "Presione Enter para volver al menú..."
}