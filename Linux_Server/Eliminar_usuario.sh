#!/bin/bash
# ==========================================
# SCRIPT INDEPENDIENTE: ELIMINAR USUARIO FTP
# ==========================================

echo "=== ELIMINAR USUARIO FTP (LINUX) ==="

echo -e "\n[*] Usuarios actuales en el servidor:"
if [ -d "/srv/ftp/usuarios" ]; then
    # Lista los usuarios y les pone un guion al principio para que se vea como lista
    ls -1 /srv/ftp/usuarios/ | sed 's/^/  - /'
else
    echo "  (No hay usuarios registrados)"
fi
echo ""

read -p "Ingrese el nombre del usuario a eliminar: " USER

if [ -z "$USER" ]; then
    echo "[!] No ingresó ningún nombre. Cancelando..."
    exit 1
fi

echo -e "\n[*] 1. Desmontando carpeta Public (Protección de archivos compartidos)..."
sudo umount -f /srv/ftp/usuarios/$USER/Public 2>/dev/null
echo "[-] Desmontaje seguro completado."

echo "[*] 2. Desconectando al usuario si está en línea..."
sudo pkill -u $USER 2>/dev/null

echo "[*] 3. Eliminando cuenta del sistema operativo Linux..."
sudo userdel -f -r $USER 2>/dev/null
echo "[-] Cuenta eliminada."

echo "[*] 4. Destruyendo jaula FTP y archivos personales..."
if [ -d "/srv/ftp/usuarios/$USER" ]; then
    sudo rm -rf /srv/ftp/usuarios/$USER
    echo "[-] Carpeta /srv/ftp/usuarios/$USER destruida."
fi

echo -e "\n[+] Proceso completado. El usuario $USER ha sido borrado totalmente."