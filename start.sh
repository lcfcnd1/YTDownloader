#!/bin/bash

# YTDownloader - Script de inicio para producción
# Configura automáticamente Nginx y inicia la aplicación Node.js

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

# Función para imprimir mensajes con color
print_message() {
    echo -e "${GREEN}[YTDownloader]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Función para verificar si un comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Función para verificar si Node.js está instalado
check_nodejs() {
    if ! command_exists node; then
        print_error "Node.js no está instalado. Instalando Node.js..."
        
        # Instalar Node.js usando NodeSource repository
        curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
        sudo apt-get install -y nodejs
        
        print_message "Node.js instalado correctamente"
    else
        NODE_VERSION=$(node --version)
        print_message "Node.js ya está instalado: $NODE_VERSION"
    fi
}

# Función para verificar si PM2 está instalado
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

# Función para verificar si Nginx está instalado
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

# Función para verificar si yt-dlp está instalado
check_ytdlp() {
    if ! command_exists yt-dlp; then
        print_info "Instalando yt-dlp..."
        
        # Instalar yt-dlp usando pip
        if command_exists pip3; then
            sudo pip3 install yt-dlp
        elif command_exists pip; then
            sudo pip install yt-dlp
        else
            # Instalar pip si no existe
            sudo apt-get update
            sudo apt-get install -y python3-pip
            sudo pip3 install yt-dlp
        fi
        
        print_message "yt-dlp instalado correctamente"
    else
        YTDLP_VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")
        print_message "yt-dlp ya está instalado: $YTDLP_VERSION"
        
        # Actualizar yt-dlp automáticamente
        print_info "Actualizando yt-dlp a la última versión..."
        if command_exists pip3; then
            sudo pip3 install --upgrade yt-dlp 2>/dev/null || true
        elif command_exists pip; then
            sudo pip install --upgrade yt-dlp 2>/dev/null || true
        fi
        
        NEW_VERSION=$(yt-dlp --version 2>/dev/null || echo "unknown")
        print_message "yt-dlp actualizado: $NEW_VERSION"
    fi
}

# Función para verificar si FFmpeg está instalado
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

# Función para instalar dependencias
install_dependencies() {
    print_info "Instalando dependencias de Node.js..."
    
    if [ ! -f "package.json" ]; then
        print_error "No se encontró package.json en el directorio actual"
        exit 1
    fi
    
    # Instalar dependencias
    npm install --production
    
    print_message "Dependencias instaladas correctamente"
}

# Función para crear directorios necesarios
create_directories() {
    print_info "Creando directorios necesarios..."
    
    # Crear directorios del proyecto
    mkdir -p logs
    mkdir -p downloads/audio
    mkdir -p downloads/video
    mkdir -p public
    
    print_message "Directorios creados correctamente"
}

# Función para crear configuración de Nginx
create_nginx_config() {
    print_info "Creando configuración de Nginx..."
    
    local nginx_config_file="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local nginx_enabled_link="$NGINX_SITES_ENABLED/$APP_NAME"
    
    # Verificar si ya existe la configuración
    if [ -f "$nginx_config_file" ]; then
        print_warning "La configuración de Nginx ya existe. Respaldando..."
        sudo cp "$nginx_config_file" "${nginx_config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Crear configuración de Nginx
    sudo tee "$nginx_config_file" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # Logs
    access_log /var/log/nginx/${APP_NAME}_access.log;
    error_log /var/log/nginx/${APP_NAME}_error.log;
    
    # Configuración para archivos grandes (videos)
    client_max_body_size 500M;
    client_body_timeout 300s;
    client_header_timeout 300s;
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
    
    # Headers de seguridad
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Proxy para la aplicación Node.js
    location /ytdownloader/ {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Configuración para descargas
        proxy_buffering off;
        proxy_request_buffering off;
    }
    
    # Configuración específica para descargas
    location /ytdownloader/api/download/ {
        proxy_pass http://127.0.0.1:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        
        # Configuración para archivos grandes
        proxy_buffering off;
        proxy_request_buffering off;
        proxy_read_timeout 600s;
        proxy_send_timeout 600s;
    }
    
    # Servir archivos estáticos directamente desde Nginx
    location /ytdownloader/static/ {
        alias $PROJECT_DIR/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Health check endpoint
    location /ytdownloader/health {
        proxy_pass http://127.0.0.1:$APP_PORT/health;
        access_log off;
    }
}
EOF

    print_message "Configuración de Nginx creada en $nginx_config_file"
}

# Función para habilitar sitio en Nginx
enable_nginx_site() {
    print_info "Habilitando sitio en Nginx..."
    
    local nginx_config_file="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local nginx_enabled_link="$NGINX_SITES_ENABLED/$APP_NAME"
    
    # Crear enlace simbólico si no existe
    if [ ! -L "$nginx_enabled_link" ]; then
        sudo ln -s "$nginx_config_file" "$nginx_enabled_link"
        print_message "Sitio habilitado en Nginx"
    else
        print_warning "El sitio ya está habilitado en Nginx"
    fi
}

# Función para verificar configuración de Nginx
test_nginx_config() {
    print_info "Verificando configuración de Nginx..."
    
    if sudo nginx -t; then
        print_message "Configuración de Nginx válida"
    else
        print_error "Error en la configuración de Nginx"
        exit 1
    fi
}

# Función para recargar Nginx
reload_nginx() {
    print_info "Recargando Nginx..."
    
    sudo systemctl reload nginx
    
    if [ $? -eq 0 ]; then
        print_message "Nginx recargado correctamente"
    else
        print_error "Error recargando Nginx"
        exit 1
    fi
}

# Función para iniciar la aplicación
start_application() {
    local mode=${1:-production}
    
    print_info "Iniciando aplicación en modo $mode..."
    
    # Detener aplicación si está corriendo
    pm2 stop $APP_NAME 2>/dev/null || true
    pm2 delete $APP_NAME 2>/dev/null || true
    
    # Iniciar aplicación
    if [ "$mode" = "production" ]; then
        NODE_ENV=production BASE_PATH=/ytdownloader pm2 start ecosystem.config.js --env production
    else
        NODE_ENV=development BASE_PATH=/ytdownloader pm2 start ecosystem.config.js --env development
    fi
    
    # Guardar configuración de PM2
    pm2 save
    pm2 startup | grep -E '^sudo' | bash 2>/dev/null || true
    
    print_message "Aplicación iniciada correctamente"
}

# Función para mostrar estado
show_status() {
    print_info "Estado de la aplicación:"
    echo ""
    echo "📊 PM2 Status:"
    pm2 status
    echo ""
    echo "🌐 Nginx Status:"
    sudo systemctl status nginx --no-pager -l
    echo ""
    echo "🔗 URLs disponibles:"
    echo "   - Aplicación: http://$DOMAIN/ytdownloader"
    echo "   - Health Check: http://$DOMAIN/ytdownloader/health"
    echo "   - API: http://$DOMAIN/ytdownloader/api"
    echo ""
}

# Función para limpiar archivos temporales
cleanup_temp_files() {
    print_info "Limpiando archivos temporales..."
    
    # Limpiar archivos de descarga antiguos (más de 24 horas)
    find downloads/ -type f -mtime +1 -delete 2>/dev/null || true
    
    # Limpiar logs antiguos
    find logs/ -name "*.log" -mtime +7 -delete 2>/dev/null || true
    
    print_message "Archivos temporales limpiados"
}

# Función principal
main() {
    local mode=${1:-production}
    
    print_message "🚀 Iniciando YTDownloader..."
    print_info "Modo: $mode"
    print_info "Directorio: $PROJECT_DIR"
    print_info "Dominio: $DOMAIN"
    print_info "Puerto: $APP_PORT"
    echo ""
    
    # Verificaciones previas
    check_nodejs
    check_pm2
    check_nginx
    check_ytdlp
    check_ffmpeg
    
    echo ""
    
    # Configuración del proyecto
    create_directories
    install_dependencies
    
    echo ""
    
    # Configuración de Nginx
    create_nginx_config
    enable_nginx_site
    test_nginx_config
    reload_nginx
    
    echo ""
    
    # Iniciar aplicación
    start_application $mode
    
    echo ""
    
    # Limpiar archivos temporales
    cleanup_temp_files
    
    echo ""
    
    # Mostrar estado final
    show_status
    
    print_message "✅ YTDownloader configurado e iniciado correctamente!"
    print_message "🌐 Accede a: http://$DOMAIN/ytdownloader"
    print_message "📱 Interfaz web disponible en la raíz del dominio"
    print_message "🔧 Para ver logs: pm2 logs $APP_NAME"
    print_message "🛑 Para detener: pm2 stop $APP_NAME"
    print_message "🔄 Para reiniciar: pm2 restart $APP_NAME"
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
        echo ""
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
