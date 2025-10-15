#!/bin/bash

# =========================
# YTDownloader - Script de gestión de la app Node.js
# Soporta start | stop | restart | status | logs
# Configura Nginx automáticamente con certificado existente
# =========================

set -e

APP_NAME="yt-downloader"
APP_PORT=3000
DOMAIN="sqsoft.top"
PROJECT_DIR=$(pwd)
BASE_PATH="/ytdownloader"

NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# =========================
# Funciones de log
# =========================
print_message() { echo -e "${GREEN}[YTDownloader]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

# =========================
# 1️⃣ Verificaciones previas
# =========================
check_nodejs() {
    if ! command_exists node; then
        print_error "Node.js no instalado"
        exit 1
    fi
    print_message "Node.js: $(node -v)"
}

check_pm2() {
    if ! command_exists pm2; then
        print_info "Instalando PM2..."
        sudo npm install -g pm2
    fi
    print_message "PM2: $(pm2 -v)"
}

check_nginx() {
    if ! command_exists nginx; then
        print_error "Nginx no instalado"
        exit 1
    fi
    print_message "Nginx: $(nginx -v 2>&1)"
}

# =========================
# 2️⃣ Crear directorios
# =========================
create_directories() {
    mkdir -p logs downloads/audio downloads/video public
    print_message "Directorios creados/verificados"
}

# =========================
# 3️⃣ Instalar dependencias Node
# =========================
install_dependencies() {
    if [ -f "package.json" ]; then
        npm install --production
        print_message "Dependencias Node.js instaladas"
    fi
}

# =========================
# 4️⃣ Configurar Nginx
# =========================
create_nginx_config() {
    local nginx_config_file="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local enabled_link="$NGINX_SITES_ENABLED/$APP_NAME"

    # Crear configuración
    sudo tee "$nginx_config_file" > /dev/null <<EOF
server {
    listen 80;
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    client_max_body_size 500M;
    proxy_buffering off;
    proxy_request_buffering off;

    location $BASE_PATH/ {
        proxy_pass http://127.0.0.1:$APP_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location $BASE_PATH/static/ {
        alias $PROJECT_DIR/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location $BASE_PATH/health {
        proxy_pass http://127.0.0.1:$APP_PORT/health;
        access_log off;
    }
}
EOF

    # Habilitar sitio
    if [ ! -L "$enabled_link" ]; then
        sudo ln -s "$nginx_config_file" "$enabled_link"
    fi

    # Verificar y recargar
    sudo nginx -t
    sudo systemctl reload nginx
    print_message "Nginx recargado"
}

# =========================
# 5️⃣ Gestión de la app
# =========================
start_app() {
    print_info "Deteniendo app si existiera..."
    pm2 delete $APP_NAME 2>/dev/null || true

    print_info "Iniciando app con BASE_PATH=$BASE_PATH..."
    export BASE_PATH=$BASE_PATH
    pm2 start ecosystem.config.js --env production
    pm2 save
}

stop_app() {
    print_info "Deteniendo app..."
    pm2 stop $APP_NAME 2>/dev/null || true
    pm2 delete $APP_NAME 2>/dev/null || true
    print_message "App detenida"
}

restart_app() {
    stop_app
    start_app
}

status_app() {
    pm2 status $APP_NAME
}

logs_app() {
    pm2 logs $APP_NAME
}

# =========================
# 6️⃣ Main
# =========================
case "$1" in
    start|"")
        check_nodejs
        check_pm2
        check_nginx
        create_directories
        install_dependencies
        create_nginx_config
        start_app
        ;;
    stop)
        stop_app
        ;;
    restart)
        restart_app
        ;;
    status)
        status_app
        ;;
    logs)
        logs_app
        ;;
    *)
        echo "Uso: $0 [start|stop|restart|status|logs]"
        exit 1
        ;;
esac
