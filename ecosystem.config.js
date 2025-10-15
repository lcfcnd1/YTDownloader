module.exports = {
  apps: [{
    name: 'yt-downloader',
    script: 'server.js',
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    env: {
      NODE_ENV: 'development',
      PORT: 3000,
      BASE_PATH: '/ytdownloader'
    },
    env_production: {
      NODE_ENV: 'production',
      PORT: 3000,
      BASE_PATH: '/ytdownloader'
    },
    // Configuración de logs
    log_file: './logs/combined.log',
    out_file: './logs/out.log',
    error_file: './logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z',
    
    // Configuración de restart
    min_uptime: '10s',
    max_restarts: 10,
    restart_delay: 4000,
    
    // Configuración de memoria
    max_memory_restart: '500M',
    
    // Variables de entorno específicas
    env_vars: {
      TZ: 'UTC'
    },
    
    // Configuración de cluster (si se necesita escalar)
    exec_mode: 'fork', // Cambiar a 'cluster' si se necesita escalar horizontalmente
    
    // Configuración de cron para restart automático (opcional)
    //cron_restart: '0 4 * * *', // Restart diario a las 4 AM
    
    // Configuración de salud
    health_check_grace_period: 3000,
    
    // Configuración de kill timeout
    kill_timeout: 5000,
    
    // Configuración de interpeter
    interpreter: 'node',
    
    // Configuración de cwd
    cwd: './',
    
    // Configuración de merge logs
    merge_logs: true,
    
    // Configuración de time
    time: true,
    
    // Configuración de listen timeout
    listen_timeout: 8000,
    
    // Configuración de increment
    increment_var: 'PORT',
    
    // Scripts personalizados
    post_update: ['npm install'],
    
    // Configuración de source map
    source_map_support: true,
    
    // Configuración de node args
    node_args: '--max-old-space-size=512',
    
    // Configuración de ignore watch
    ignore_watch: [
      'node_modules',
      'logs',
      'downloads',
      '.git',
      '*.log'
    ],
    
    // Configuración de watch options
    watch_options: {
      followSymlinks: false,
      usePolling: true,
      interval: 1000
    }
  }],

  // Configuración de deploy (para despliegues automatizados)
  deploy: {
    production: {
      user: 'root',
      host: 'sqsoft.top',
      ref: 'origin/main',
      repo: 'git@github.com:usuario/yt-downloader.git',
      path: '/var/www/yt-downloader',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production',
      'pre-setup': 'apt update && apt install git -y'
    }
  }
};
