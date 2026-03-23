#!/bin/bash
# ======================================================
# Preparar Bóveda Segura FTP (Práctica 7)
# ======================================================

function Preparar_Repositorio() {
    echo "======================================================"
    echo "  Preparando Bóveda Segura FTP para Instaladores"
    echo "======================================================"

    REPO_BASE="/srv/ftp/repo"
    WORK_DIR="/tmp/deb_downloads"

    if ! dpkg -l vsftpd 2>/dev/null | grep -q "^ii"; then
        echo "[-] vsftpd no está instalado. Instálalo primero (Opción 1 -> 4)."
        read -p "Presione Enter..."
        return
    fi

    echo "[*] Creando usuario 'repo' sin enjaular..."
    if ! id "repo" &>/dev/null; then
        sudo mkdir -p "$REPO_BASE"
        sudo useradd repo -d "$REPO_BASE" -s /bin/false
        echo "repo:repo123" | sudo chpasswd
        echo "  [+] Usuario repo creado (Pass: repo123)."
    else
        echo "  [+] Usuario repo ya existe."
    fi

    if ! grep -q "^/bin/false$" /etc/shells; then
        echo "/bin/false" | sudo tee -a /etc/shells >/dev/null
    fi

    sudo touch /etc/vsftpd.chroot_list
    if ! grep -q "^repo$" /etc/vsftpd.chroot_list; then
        echo "repo" | sudo tee -a /etc/vsftpd.chroot_list >/dev/null
    fi
    if ! grep -q "^chroot_list_enable=YES" /etc/vsftpd.conf; then
        echo "chroot_list_enable=YES" | sudo tee -a /etc/vsftpd.conf >/dev/null
        echo "chroot_list_file=/etc/vsftpd.chroot_list" | sudo tee -a /etc/vsftpd.conf >/dev/null
    fi
    sudo systemctl restart vsftpd

    echo "[*] Creando estructura de directorios..."
    for d in "$REPO_BASE/http/Linux/Apache" "$REPO_BASE/http/Linux/Nginx" "$REPO_BASE/http/Linux/Tomcat"; do
        sudo mkdir -p "$d"
    done

    sudo mkdir -p "$WORK_DIR"
    cd "$WORK_DIR" || return

    sudo apt-get update -qq

    descargar_paquete() {
        local paquete="$1"
        local destino="$2"
        echo "  Descargando $paquete..."
        sudo rm -f ${paquete}_*.deb 2>/dev/null
        sudo apt-get download "$paquete" 2>/dev/null
        local deb=$(ls ${paquete}_*.deb 2>/dev/null | head -1)
        if [[ -n "$deb" ]]; then
            sudo mv "$deb" "$destino/"
            sudo bash -c "sha256sum '$destino/$deb' | awk '{print \$1}' > '$destino/$deb.sha256'"
            echo "  [+] $deb asegurado."
        else
            echo "  [-] Error al descargar $paquete."
        fi
    }

    descargar_paquete "apache2" "$REPO_BASE/http/Linux/Apache"
    descargar_paquete "nginx" "$REPO_BASE/http/Linux/Nginx"
    
    if apt-cache show tomcat10 &>/dev/null; then
        descargar_paquete "tomcat10" "$REPO_BASE/http/Linux/Tomcat"
    elif apt-cache show tomcat9 &>/dev/null; then
        descargar_paquete "tomcat9" "$REPO_BASE/http/Linux/Tomcat"
    fi

    sudo chown -R repo:repo "$REPO_BASE"
    sudo chmod -R 755 "$REPO_BASE"

    echo "======================================================"
    echo "[+] Bóveda lista en $REPO_BASE"
    echo "======================================================"
    read -p "Presione Enter para continuar..."
}}