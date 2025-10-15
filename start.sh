#!/bin/bash

# YTDownloader - Script de inicio para producción
# Configura automáticamente Nginx y arranca la aplicación Node.js con BASE_PATH

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
APP_NAME="yt-downloader"
APP_PORT=3000
DOMAIN="sqsoft.top"
NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"
PROJECT_DIR=$(pwd)
BASE_PATH="/ytdownloader"

# Funciones de mensaje
print_message() { echo -e "${GREEN}[YTDownloader]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

# Función para verificar comando
command_exists() { command -v "$1" >/dev/null 2>&1; }

# Verificaciones
check_nodejs() {
    if ! command_exists node; then
        print_error "Node.js no está instalado. Instalando Node.js..."
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        print_message "Node.js instalado correctamente"
    else
        NODE_VERSION=$(node --version)
        print_message "Node.js ya está instalado: $NODE_VERSION"
    fi
}

check_pm2() {
    if ! command_exists pm2; then
        print_info "Instalando PM2 globalmente..."
        sudo npm install -g pm2
        print_message "PM2 instalado correctamente"
    else
        PM2_VERSION=$(pm2 --version)
        print_message "PM2 ya está instalado: $PM2_VERSION"
    fi
}

check_nginx() {
    if ! command_exists nginx; then
        print_info "Instalando Nginx..."
        sudo apt-get update
        sudo apt-get install -y nginx
        sudo systemctl enable nginx
        print_message "Nginx instalado correctamente"
    else
        NGINX_VERSION=$(nginx -v 2>&1 | cut -d' ' -f3)
        print_message "Nginx ya está instalado: $NGINX_VERSION"
    fi
}

check_ytdlp() {
    if ! command_exists yt-dlp; then
        print_info "Instalando yt-dlp..."
        if command_exists pip3; then
            sudo pip3 install --break-system-packages yt-dlp
        else
            sudo apt-get update
            sudo apt-get install -y python3-pip
            sudo pip3 install --break-system-packages yt-dlp
        fi
        print_message "yt-dlp instalado correctamente"
    else
        YTDLP_VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")
        print_message "yt-dlp ya está instalado: $YTDLP_VERSION"
        sudo pip3 install --upgrade --break-system-packages yt-dlp || true
    fi
}

check_ffmpeg() {
    if ! command_exists ffmpeg; then
        print_info "Instalando FFmpeg..."
        sudo apt-get update
        sudo apt-get install -y ffmpeg
        print_message "FFmpeg instalado correctamente"
    else
        FFMPEG_VERSION=$(ffmpeg -version 2>&1 | head -n1 | cut -d' ' -f3)
        print_message "FFmpeg ya está instalado: $FFMPEG_VERSION"
    fi
}

install_dependencies() {
    print_info "Instalando dependencias Node.js..."
    if [ ! -f "package.json" ]; then
        print_error "No se encontró package.json en el directorio actual"
        exit 1
    fi
    npm install --production
    print_message "Dependencias instaladas correctamente"
}

create_directories() {
    print_info "Creando directorios necesarios..."
    mkdir -p logs downloads/audio downloads/video public
    print_message "Directorios creados correctamente"
}

create_nginx_config() {
    print_info "Creando configuración de Nginx..."
    local nginx_config_file="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local nginx_enabled_link="$NGINX_SITES_ENABLED/$APP_NAME"

    if [ -f "$nginx_config_file" ]; then
        print_warning "La configuración de Nginx ya existe. Respaldando..."
        sudo cp "$nginx_config_file" "${nginx_config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi

    sudo tee "$nginx_config_file" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log /var/log/nginx/${APP_NAME}_error.log;

    client_max_body_size 500M;

    location $BASE_PATH/ {
        proxy_pass http://127.0.0.1:$APP_PORT$BASE_PATH/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;

        proxy_buffering off;
        proxy_request_buffering off;
    }

    location $BASE_PATH/static/ {
        alias $PROJECT_DIR/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location $BASE_PATH/health {
        proxy_pass http://127.0.0.1:$APP_PORT$BASE_PATH/health;
        access_log off;
    }
}
EOF

    print_message "Configuración de Nginx creada en $nginx_config_file"
}

enable_nginx_site() {
    local nginx_config_file="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local nginx_enabled_link="$NGINX_SITES_ENABLED/$APP_NAME"
    if [ ! -L "$nginx_enabled_link" ]; then
        sudo ln -s "$nginx_config_file" "$nginx_enabled_link"
        print_message "Sitio habilitado en Nginx"
    else
        print_warning "El sitio ya está habilitado en Nginx"
    fi
}

test_nginx_config() {
    print_info "Verificando configuración de Nginx..."
    sudo nginx -t
    print_message "Configuración de Nginx válida"
}

reload_nginx() {
    print_info "Recargando Nginx..."
    sudo systemctl reload nginx
    print_message "Nginx recargado correctamente"
}

start_application() {
    local mode=${1:-production}

    print_info "Deteniendo aplicación existente si la hubiera..."
    pm2 stop $APP_NAME 2>/dev/null || true
    pm2 delete $APP_NAME 2>/dev/null || true

    print_info "Exportando variables de entorno..."
    export NODE_ENV=$mode
    export BASE_PATH=$BASE_PATH

    print_info "Iniciando aplicación en modo $mode..."
    pm2 start ecosystem.config.js --env $mode

    pm2 save
    pm2 startup | grep -E '^sudo' | bash 2>/dev/null || true
    print_message "Aplicación iniciada correctamente con BASE_PATH=$BASE_PATH"
}

show_status() {
    print_info "Estado de la aplicación:"
    echo ""
    pm2 status
    echo ""
    sudo systemctl status nginx --no-pager -l
    echo ""
    echo "🌐 URLs disponibles:"
    echo "   - Aplicación: http://$DOMAIN$BASE_PATH"
    echo "   - Health Check: http://$DOMAIN$BASE_PATH/health"
    echo "   - API: http://$DOMAIN$BASE_PATH/api"
}

cleanup_temp_files() {
    print_info "Limpiando archivos temporales..."
    find downloads/ -type f -mtime +1 -delete 2>/dev/null || true
    find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
    print_message "Archivos temporales limpiados"
}

main() {
    local mode=${1:-production}
    print_message "🚀 Iniciando YTDownloader..."
    print_info "Modo: $mode"
    print_info "Directorio: $PROJECT_DIR"
    print_info "Dominio: $DOMAIN"
    print_info "Puerto: $APP_PORT"

    check_nodejs
    check_pm2
    check_nginx
    check_ytdlp
    check_ffmpeg

    create_directories
    install_dependencies

    create_nginx_config
    enable_nginx_site
    test_nginx_config
    reload_nginx

    start_application $mode
    cleanup_temp_files
    show_status

    print_message "✅ YTDownloader configurado e iniciado correctamente!"
}

# Manejo de argumentos
case "${1:-}" in
    "dev"|"development")
        main "development"
        ;;
    "prod"|"production"|"")
        main "production"
        ;;
    "stop")
        print_info "Deteniendo YTDownloader..."
        pm2 stop $APP_NAME 2>/dev/null || true
        pm2 delete $APP_NAME 2>/dev/null || true
        print_message "Aplicación detenida"
        ;;
    "restart")
        print_info "Reiniciando YTDownloader..."
        pm2 restart $APP_NAME
        print_message "Aplicación reiniciada"
        ;;
    "status")
        show_status
        ;;
    "logs")
        pm2 logs $APP_NAME
        ;;
    "help"|"-h"|"--help")
        echo "Uso: $0 [comando]"
        echo "Comandos:"
        echo "  (sin argumentos)  - Iniciar en modo producción"
        echo "  dev               - Iniciar en modo desarrollo"
        echo "  stop              - Detener la aplicación"
        echo "  restart           - Reiniciar la aplicación"
        echo "  status            - Mostrar estado de la aplicación"
        echo "  logs              - Mostrar logs de la aplicación"
        echo "  help              - Mostrar esta ayuda"
        ;;
    *)
        print_error "Comando desconocido: $1"
        print_info "Usa '$0 help' para ver los comandos disponibles"
        exit 1
        ;;
esac
