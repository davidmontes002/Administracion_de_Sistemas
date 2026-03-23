#!/bin/bash
# ======================================================
# Funciones SSL/TLS (Práctica 7)
# ======================================================

CERT_DIR="/etc/ssl/practica7"
CERT_FILE="$CERT_DIR/server.crt"
KEY_FILE="$CERT_DIR/server.key"

function Generar_Certificado() {
    if [ ! -f "$CERT_FILE" ]; then
        echo "[*] Generando certificado digital autofirmado..."
        sudo mkdir -p "$CERT_DIR"
        sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout "$KEY_FILE" -out "$CERT_FILE" -subj "/C=MX/ST=Estado/L=Ciudad/O=Reprobados/CN=localhost" 2>/dev/null
        echo "[+] Certificado creado."
    fi
}

function Activar_SSL_Apache() {
    Generar_Certificado
    echo "[*] Configurando SSL en Apache2..."
    sudo a2enmod ssl rewrite >/dev/null 2>&1
    
    sudo bash -c "cat > /etc/apache2/sites-available/default-ssl.conf <<EOF
<VirtualHost *:443>
    ServerName localhost
    DocumentRoot /var/www/html
    SSLEngine on
    SSLCertificateFile $CERT_FILE
    SSLCertificateKeyFile $KEY_FILE
</VirtualHost>
EOF"
    
    sudo sed -i -E "s|</VirtualHost>|    Redirect permanent / https://localhost/\n</VirtualHost>|g" /etc/apache2/sites-available/000-default.conf
    sudo a2ensite default-ssl.conf >/dev/null 2>&1
    if ! grep -q "Listen 443" /etc/apache2/ports.conf; then
        echo "Listen 443" | sudo tee -a /etc/apache2/ports.conf >/dev/null
    fi
    sudo systemctl restart apache2
    echo "[+] SSL Activo en Apache2 (Puerto 443)."
}

function Activar_SSL_Nginx() {
    local PUERTO=$1
    Generar_Certificado
    echo "[*] Configurando SSL en Nginx..."
    sudo bash -c "cat > /etc/nginx/sites-available/default <<EOF
server {
    listen $PUERTO default_server;
    server_name localhost;
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl default_server;
    server_name localhost;
    ssl_certificate $CERT_FILE;
    ssl_certificate_key $KEY_FILE;
    root /var/www/nginx;
    index index.html;
}
EOF"
    sudo systemctl restart nginx
    echo "[+] SSL Activo en Nginx (Puerto 443)."
}

function Activar_SSL_Tomcat() {
    Generar_Certificado
    echo "[*] Configurando SSL en Tomcat..."
    local p12="$CERT_DIR/server.p12"
    local pass="reprobados123"

    sudo openssl pkcs12 -export -in "$CERT_FILE" -inkey "$KEY_FILE" -out "$p12" -name tomcat -passout pass:"$pass" 2>/dev/null
    sudo chown tomcat:tomcat "$p12" 2>/dev/null

    local server_xml="/opt/tomcat/conf/server.xml"
    if [ -f "$server_xml" ]; then
        sudo sed -i '/<\/Service>/i \
    <Connector port="8443" protocol="org.apache.coyote.http11.Http11NioProtocol" maxThreads="150" SSLEnabled="true">\n \
        <SSLHostConfig>\n \
            <Certificate certificateKeystoreFile="'$p12'" certificateKeystorePassword="'$pass'" type="RSA" />\n \
        </SSLHostConfig>\n \
    </Connector>' "$server_xml"
        sudo systemctl restart tomcat
        echo "[+] SSL Activo en Tomcat (Puerto 8443)."
    fi
}

function Activar_SSL_FTP() {
    Generar_Certificado
    echo "[*] Blindando vsftpd con FTPS..."
    sudo sed -i 's/ssl_enable=NO/ssl_enable=YES/' /etc/vsftpd.conf 2>/dev/null
    if ! grep -q "rsa_cert_file=$CERT_FILE" /etc/vsftpd.conf; then
        sudo bash -c "cat >> /etc/vsftpd.conf <<EOF
ssl_enable=YES
rsa_cert_file=$CERT_FILE
rsa_private_key_file=$KEY_FILE
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO
force_local_data_ssl=YES
force_local_logins_ssl=YES
EOF"
    fi
    sudo systemctl restart vsftpd
    echo "[+] FTPS Activo."
    read -p "Presione Enter..."
}