#!/bin/bash

# YTDownloader - Script de inicio para producción
# Configura automáticamente Nginx y levanta la app Node.js con PM2

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
        print_error "Node.js no está instalado. Instala Node.js antes de continuar."
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
        print_info "Instalando Nginx..."
        sudo apt-get update
        sudo apt-get install -y nginx
    fi
    print_message "Nginx: $(nginx -v 2>&1)"
}

# =========================
# 2️⃣ Crear directorios
# =========================
create_directories() {
    print_info "Creando directorios..."
    mkdir -p logs downloads/audio downloads/video public
    print_message "Directorios creados"
}

# =========================
# 3️⃣ Instalar dependencias Node
# =========================
install_dependencies() {
    print_info "Instalando dependencias Node.js..."
    npm install --production
    print_message "Dependencias instaladas"
}

# =========================
# 4️⃣ Configurar Nginx
# =========================
create_nginx_config() {
    local nginx_config_file="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local enabled_link="$NGINX_SITES_ENABLED/$APP_NAME"

    if [ ! -f "$nginx_config_file" ]; then
        sudo tee "$nginx_config_file" > /dev/null <<EOF
server {
    listen 80;
    listen 443 ssl;
    server_name $DOMAIN;

    # SSL certificado existente
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    client_max_body_size 500M;
    proxy_buffering off;
    proxy_request_buffering off;

    # Proxy a la app Node.js
    location $BASE_PATH/ {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
        print_message "Configuración Nginx creada"
    else
        print_warning "Configuración Nginx ya existe"
    fi

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
# 5️⃣ Iniciar aplicación
# =========================
start_application() {
    print_info "Deteniendo app existente si existe..."
    pm2 delete $APP_NAME 2>/dev/null || true

    print_info "Iniciando app en modo producción con BASE_PATH=$BASE_PATH..."
    pm2 start ecosystem.config.js --env production
    pm2 save
}

# =========================
# 6️⃣ Main
# =========================
main() {
    print_message "🚀 Iniciando $APP_NAME..."
    check_nodejs
    check_pm2
    check_nginx
    create_directories
    install_dependencies
    create_nginx_config
    start_application
    print_message "✅ $APP_NAME iniciado en https://$DOMAIN$BASE_PATH"
}

# =========================
# Ejecutar
# =========================
main
