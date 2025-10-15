#!/bin/bash

APP_NAME="yt-downloader"
APP_PORT=3000
DOMAIN="sqsoft.top"
PROJECT_DIR=$(pwd)

NGINX_SITES_AVAILABLE="/etc/nginx/sites-available"
NGINX_SITES_ENABLED="/etc/nginx/sites-enabled"

print_message() { echo -e "\033[0;32m[YTDownloader]\033[0m $1"; }

command_exists() { command -v "$1" >/dev/null 2>&1; }

check_nodejs() {
    if ! command_exists node; then
        echo "Node.js no instalado"; exit 1
    fi
}

check_pm2() {
    if ! command_exists pm2; then
        npm install -g pm2
    fi
}

check_nginx() {
    if ! command_exists nginx; then
        apt-get update && apt-get install -y nginx
    fi
}

create_directories() {
    mkdir -p logs downloads/audio downloads/video public
}

install_dependencies() {
    npm install --production
}

create_nginx_config() {
    local nginx_config_file="$NGINX_SITES_AVAILABLE/$APP_NAME"
    local enabled_link="$NGINX_SITES_ENABLED/$APP_NAME"

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

    location /ytdownloader/ {
        proxy_pass http://127.0.0.1:$APP_PORT/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    location /ytdownloader/static/ {
        alias $PROJECT_DIR/public/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    location /ytdownloader/health {
        proxy_pass http://127.0.0.1:$APP_PORT/health;
        access_log off;
    }
}
EOF

    [ ! -L "$enabled_link" ] && sudo ln -s "$nginx_config_file" "$enabled_link"

    sudo nginx -t
    sudo systemctl reload nginx
    print_message "Nginx recargado"
}

stop_application() {
    pm2 delete $APP_NAME 2>/dev/null || true
}

start_application() {
    stop_application
    pm2 start ecosystem.config.js --env production
    pm2 save
}

main() {
    print_message "🚀 Iniciando $APP_NAME..."
    check_nodejs
    check_pm2
    check_nginx
    create_directories
    install_dependencies
    create_nginx_config
    start_application
    print_message "✅ $APP_NAME iniciado en https://$DOMAIN/ytdownloader"
}

main
