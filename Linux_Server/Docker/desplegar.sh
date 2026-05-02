#!/bin/bash

# ==========================================
# Script de Despliegue Total - Tarea 10
# (Incluye Instalación de Docker)
# ==========================================

echo "=========================================="
echo "Fase 1: Instalación de Dependencias"
echo "=========================================="
# Actualizamos el sistema e instalamos Docker y Compose
sudo apt update
sudo apt install docker.io docker-compose-v2 -y

# Agregamos al usuario actual al grupo de docker para uso futuro
echo ">> Configurando permisos para el usuario: $USER"
sudo usermod -aG docker $USER

echo "=========================================="
echo "Fase 2: Creación del Entorno"
echo "=========================================="
DIRECTORIO="tarea10_entorno"

echo ">> Creando directorio del proyecto en $DIRECTORIO..."
mkdir -p $DIRECTORIO/{web,respaldos}
cd $DIRECTORIO

echo ">> Generando Dockerfile para el Servidor Web (Seguro y Ligero)..."
cat << 'EOF' > web/Dockerfile
FROM nginxinc/nginx-unprivileged:alpine

# Cambiamos a root temporalmente para modificar configuraciones
USER root

# Eliminamos firmas del servidor (Server Tokens off)
RUN sed -i '/http {/a \    server_tokens off;' /etc/nginx/nginx.conf

# Volvemos al usuario no privilegiado (ID 101) por seguridad
USER 101
EOF

echo ">> Creando un index.html de prueba..."
cat << 'EOF' > web/index.html
<!DOCTYPE html>
<html>
<head><title>Tarea 10 - Entorno Seguro</title></head>
<body>
    <h1>¡El servidor web no-root está funcionando!</h1>
    <p>Sube archivos por FTP para verlos aquí.</p>
</body>
</html>
EOF

echo ">> Generando docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
services:
  web:
    build: ./web
    container_name: servidor_web
    ports:
      - "8080:8080"
    volumes:
      - web_content:/usr/share/nginx/html
    networks:
      - infra_red
    deploy:
      resources:
        limits:
          cpus: '0.50'
          memory: 512M

  db:
    image: postgres:15-alpine
    container_name: base_datos
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: password_seguro
      POSTGRES_DB: app_db
    volumes:
      - db_data:/var/lib/postgresql/data
      - ./respaldos:/respaldos_host
    networks:
      - infra_red

  ftp:
    image: fauria/vsftpd
    container_name: servidor_ftp
    environment:
      FTP_USER: usuarioftp
      FTP_PASS: passwordftp
      PASV_ADDRESS: 127.0.0.1
    ports:
      - "21:21"
      - "20:20"
      - "21100-21110:21100-21110"
    volumes:
      - web_content:/home/vsftpd/usuarioftp
    networks:
      - infra_red

networks:
  infra_red:
    name: infra_red
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  db_data:
    name: db_data
  web_content:
    name: web_content
EOF

echo "=========================================="
echo "Fase 3: Despliegue de Contenedores"
echo "=========================================="
# Usamos sudo aquí para evitar errores de sesión no actualizada
sudo docker volume create web_content
sudo docker run --rm -v web_content:/target -v $(pwd)/web/index.html:/source/index.html alpine cp /source/index.html /target/index.html

sudo docker compose up -d --build

echo "=========================================="
echo "¡Entorno desplegado con éxito!"
echo "=========================================="
echo "IMPORTANTE: Para empezar a hacer tus pruebas sin usar 'sudo',"
echo "ejecuta este comando ahora mismo en tu terminal:"
echo "newgrp docker"
echo "=========================================="
