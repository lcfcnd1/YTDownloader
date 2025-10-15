#!/bin/bash

# YTDownloader - Script de inicio para producción
# Configura automáticamente Nginx y levanta la app Node.js con PM2

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
APP_NAME="yt-downloader"
APP_PORT=3000
DOMAIN="sqsoft.top"
BASE_PATH="/ytdownloader"
PROJECT_DIR=$(pwd)
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
SSL_CERT="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
SSL_KEY="/etc/letsencrypt/live/$DOMAIN/privkey.pem"

# Funciones para imprimir mensajes
print_message() { echo -e "${GREEN}[YTDownloader]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Verificar comandos
command_exists() { command -v "$1" >/dev/null 2>&1; }

check_nodejs() {
    if ! command_exists node; then
        print_error "Node.js no está instalado. Instalando..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        print_message "Node.js instalado"
    else
        NODE_VERSION=$(node -v)
        print_message "Node.js ya instalado: $NODE_VERSION"
    fi
}

check_pm2() {
    if ! command_exists pm2; then
        print_info "Instalando PM2 globalmente..."
        sudo npm install -g pm2
        print_message "PM2 instalado"
    else
        PM2_VERSION=$(pm2 -v)
        print_message "PM2 ya instalado: $PM2_VERSION"
    fi
}

check_ffmpeg() {
    if ! command_exists ffmpeg; then
        print_info "Instalando FFmpeg..."
        sudo apt-get update
        sudo apt-get install -y ffmpeg
        print_message "FFmpeg instalado"
    else
        FFMPEG_VERSION=$(ffmpeg -version | head -n1)
        print_message "FFmpeg ya instalado: $FFMPEG_VERSION"
    fi
}

check_ytdlp() {
    if ! command_exists yt-dlp; then
        print_info "Instalando yt-dlp..."
        sudo apt-get install -y python3-pip
        sudo pip3 install --upgrade yt-dlp
        print_message "yt-dlp instalado"
    else
        YTDLP_VERSION=$(yt-dlp --version)
        print_message "yt-dlp ya instalado: $YTDLP_VERSION"
    fi
}

install_dependencies() {
    print_info "Instalando dependencias Node.js..."
    npm install --production
    print_message "Dependencias instaladas"
}

create_directories() {
    print_info "Creando directorios necesarios..."
    mkdir -p logs downloads/audio downloads/video public
    print_message "Directorios listos"
}

create_nginx_config() {
    print_info "Creando configuración Nginx para SSL y /ytdownloader/..."

    local nginx_conf="$NGINX_SITES_AVAILABLE/$APP_NAME"
    
    sudo tee "$nginx_conf" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log /var/log/nginx/${APP_NAME}_error.log;

    client_max_body_size 500M;
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
    proxy_connect_timeout 600s;

    # Headers de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;

    # Proxy /ytdownloader/
    location $BASE_PATH/ {
        proxy_pass http://127.0.0.1:$APP_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off;
    }

    # Descargas grandes
    location $BASE_PATH/api/download/ {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }

    # Archivos estáticos
    location $BASE_PATH/static/ {
        alias $PROJECT_DIR/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Health check
    location $BASE_PATH/health {
        proxy_pass http://127.0.0.1:$APP_PORT/health;
        access_log off;
    }
}
EOF

    print_message "Configuración Nginx creada en $nginx_conf"
}

enable_nginx_site() {
    local nginx_conf="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local nginx_link="$NGINX_SITES_ENABLED/$APP_NAME"

    if [ ! -L "$nginx_link" ]; then
        sudo ln -s "$nginx_conf" "$nginx_link"
        print_message "Sitio habilitado en Nginx"
    else
        print_warning "Sitio ya habilitado"
    fi
}

reload_nginx() {
    print_info "Recargando Nginx..."
    sudo nginx -t
    sudo systemctl reload nginx
    print_message "Nginx recargado"
}

start_application() {
    print_info "Iniciando aplicación con PM2..."
    pm2 stop $APP_NAME 2>/dev/null || true
    pm2 delete $APP_NAME 2>/dev/null || true

    NODE_ENV=production BASE_PATH=$BASE_PATH pm2 start ecosystem.config.js --env production
    pm2 save
    print_message "Aplicación iniciada"
}

cleanup_temp_files() {
    print_info "Limpiando archivos temporales..."
    find downloads/ -type f -mtime +1 -delete 2>/dev/null || true
    find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
    print_message "Archivos temporales limpiados"
}

show_status() {
    print_info "Estado de la app y Nginx:"
    pm2 status
    sudo systemctl status nginx --no-pager -l
    echo "Aplicación accesible en: https://$DOMAIN$BASE_PATH"
}

main() {
    print_message "🚀 Iniciando YTDownloader..."
    echo ""

    check_nodejs
    check_pm2
    check_ffmpeg
    check_ytdlp
    create_directories
    install_dependencies
    create_nginx_config
    enable_nginx_site
    reload_nginx
    start_application
    cleanup_temp_files
    show_status
}

case "${1:-}" in
    stop)
        print_info "Deteniendo aplicación..."
        pm2 stop $APP_NAME 2>/dev/null || true
        pm2 delete $APP_NAME 2>/dev/null || true
        ;;
    restart)
        main
        ;;
    status)
        show_status
        ;;
    logs)
        pm2 logs $APP_NAME
        ;;
    *)
        main
        ;;
esac
