# YTDownloader 🎬

Una aplicación Node.js moderna para buscar y descargar videos de YouTube en formato MP3 y MP4.

## ✨ Características

- 🔍 **Búsqueda de videos**: Busca videos en YouTube con resultados en tiempo real
- 🎵 **Descarga de audio**: Convierte y descarga audio en formato MP3 (128 kbps)
- 🎬 **Descarga de video**: Descarga videos en formato MP4 de alta calidad
- 🌐 **Interfaz web moderna**: Interfaz responsive y atractiva
- 🚀 **Optimizado para producción**: Configuración completa con PM2 y Nginx
- 🔒 **Seguridad**: Middleware de seguridad y validaciones
- 📱 **Responsive**: Funciona perfectamente en móviles y desktop

## 🛠️ Tecnologías

- **Backend**: Node.js + Express
- **Frontend**: HTML5, CSS3, JavaScript vanilla
- **Búsqueda**: youtube-search-api
- **Descarga**: yt-dlp (directamente desde línea de comandos)
- **Conversión**: yt-dlp con FFmpeg integrado
- **Procesos**: PM2
- **Proxy**: Nginx
- **Seguridad**: Helmet, CORS

## 📋 Requisitos

- Node.js 16+ 
- npm
- PM2 (se instala automáticamente)
- Nginx (se instala automáticamente)
- yt-dlp (se instala automáticamente)
- FFmpeg (se instala automáticamente)

## 🚀 Instalación y Despliegue

### Instalación automática (Recomendado)

```bash
# Clonar o descargar el proyecto
git clone <tu-repositorio>
cd yt-downloader

# Hacer ejecutable el script
chmod +x start.sh

# Ejecutar instalación y configuración automática
./start.sh production
```

El script `start.sh` hace todo automáticamente:
- ✅ Instala Node.js si no está presente
- ✅ Instala PM2 globalmente
- ✅ Instala Nginx si no está presente
- ✅ Instala yt-dlp (herramienta de descarga directa)
- ✅ Instala FFmpeg para conversión de medios
- ✅ Instala Python3-pip si no está presente
- ✅ Instala dependencias de Node.js
- ✅ Crea directorios necesarios
- ✅ Configura Nginx automáticamente
- ✅ Inicia la aplicación en modo producción
- ✅ Configura proxy inverso
- ✅ Habilita sitio web

### Instalación manual

```bash
# Instalar dependencias
npm install

# Crear directorios
mkdir -p logs downloads/audio downloads/video public

# Iniciar en desarrollo
npm run dev

# Iniciar en producción
npm start

# Con PM2
npm run pm2:start
```

## 🌐 Configuración de Nginx

El script `start.sh` configura automáticamente Nginx con:

- **Dominio**: `vps-5389639-x.dattaweb.com`
- **Puerto**: `3000`
- **Proxy inverso** configurado
- **Headers de seguridad** incluidos
- **Configuración para archivos grandes** (videos)
- **Logs separados** para la aplicación

## 📁 Estructura del Proyecto

```
yt-downloader/
├── src/
│   └── routes/
│       ├── api.js          # Rutas de API
│       └── web.js          # Rutas web
├── public/
│   └── index.html          # Interfaz web
├── downloads/
│   ├── audio/              # Archivos MP3 descargados
│   └── video/              # Archivos MP4 descargados
├── logs/                   # Logs de la aplicación
├── server.js               # Servidor principal
├── package.json            # Dependencias y scripts
├── ecosystem.config.js     # Configuración PM2
├── start.sh               # Script de inicio automático
└── README.md              # Este archivo
```

## 🔧 Scripts Disponibles

### Script de inicio (start.sh)

```bash
# Iniciar en producción
./start.sh production

# Iniciar en desarrollo
./start.sh dev

# Detener aplicación
./start.sh stop

# Reiniciar aplicación
./start.sh restart

# Ver estado
./start.sh status

# Ver logs
./start.sh logs

# Mostrar ayuda
./start.sh help
```

### Scripts npm

```bash
# Desarrollo con nodemon
npm run dev

# Iniciar servidor
npm start

# PM2 - Iniciar
npm run pm2:start

# PM2 - Detener
npm run pm2:stop

# PM2 - Reiniciar
npm run pm2:restart
```

### Scripts de mantenimiento

```bash
# Actualizar yt-dlp manualmente
chmod +x update-ytdlp.sh
./update-ytdlp.sh

# Limpiar dependencias antiguas
chmod +x install-deps.sh
./install-deps.sh

# Probar funcionamiento de yt-dlp
node test-ytdlp.js
```

## 🌍 Endpoints de la API

### Búsqueda
```
GET /ytdownloader/api/search?q=término&maxResults=10
```

### Información de video
```
GET /ytdownloader/api/video/:videoId
```

### Descarga de audio
```
GET /ytdownloader/api/download/audio/:videoId?title=título
```

### Descarga de video
```
GET /ytdownloader/api/download/video/:videoId?quality=highest&title=título
```

### Consultar formatos disponibles
```
GET /ytdownloader/api/formats/:videoId
```

**Respuesta**: Lista de formatos disponibles con sus IDs, resoluciones y detalles

### Limpiar archivos
```
DELETE /ytdownloader/api/cleanup?type=all|audio|video
```

### Health check
```
GET /ytdownloader/health
```

## 🚀 Ventajas de yt-dlp Directo

Usar `yt-dlp` directamente desde la línea de comandos ofrece:

- **✅ Mayor confiabilidad**: Sin dependencias de Node.js que pueden fallar
- **✅ Mejor compatibilidad**: Actualizaciones constantes con cambios de YouTube
- **✅ Menos errores 403**: Mejor manejo de anti-bot de YouTube
- **✅ Rendimiento superior**: Procesamiento más eficiente de videos
- **✅ Funcionalidades completas**: Acceso a todas las características de yt-dlp
- **✅ Estabilidad**: Menos problemas de compatibilidad entre versiones
- **✅ Limpieza automática**: Archivos se eliminan automáticamente después de la descarga
- **✅ Fallback inteligente**: Selección automática de calidad disponible
- **✅ Formato dinámico**: Consulta formatos disponibles antes de descargar
- **✅ Selección inteligente**: Elige el mejor formato disponible para cada video
- **✅ Audio garantizado**: Prioriza formatos con audio o combina video y audio por separado
- **✅ Combinación automática**: Si no hay formato con audio, combina automáticamente

## 🔒 Seguridad

La aplicación incluye:

- **Helmet**: Headers de seguridad HTTP
- **CORS**: Configuración de CORS
- **Validación**: Validación de URLs de YouTube
- **Límites**: Límites de tamaño de archivo
- **Logs**: Sistema de logging completo
- **PM2**: Gestión de procesos segura

## 📊 Monitoreo

### Logs de PM2
```bash
pm2 logs yt-downloader
```

### Logs de Nginx
```bash
sudo tail -f /var/log/nginx/yt-downloader_access.log
sudo tail -f /var/log/nginx/yt-downloader_error.log
```

### Estado de la aplicación
```bash
pm2 status
```

## 🚀 Despliegue en Producción

### VPS/Dedicated Server

1. **Subir archivos** al servidor
2. **Ejecutar** `./start.sh production`
3. **Verificar** que Nginx esté funcionando
4. **Acceder** a `http://vps-5389639-x.dattaweb.com/ytdownloader`

### Docker (Opcional)

```dockerfile
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3000
CMD ["npm", "start"]
```

## 🔧 Configuración Avanzada

### Variables de entorno

```bash
# Puerto de la aplicación
PORT=3000

# Entorno
NODE_ENV=production

# Dominio
DOMAIN=vps-5389639-x.dattaweb.com
```

### Configuración de PM2

Editar `ecosystem.config.js` para personalizar:

- Número de instancias
- Límites de memoria
- Configuración de logs
- Variables de entorno

## 🐛 Solución de Problemas

### Error: "FFmpeg not found"
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install ffmpeg

# CentOS/RHEL
sudo yum install ffmpeg
```

### Error: "Permission denied"
```bash
chmod +x start.sh
```

### Error: "Port already in use"
```bash
# Cambiar puerto en server.js o ecosystem.config.js
PORT=3001 npm start
```

### Error: "Nginx configuration failed"
```bash
# Verificar configuración
sudo nginx -t

# Ver logs
sudo tail -f /var/log/nginx/error.log
```

## 📈 Optimizaciones

### Para tráfico bajo (4 usuarios)
- Una instancia PM2
- Límite de memoria: 500MB
- Cache de archivos descargados
- Limpieza automática de archivos antiguos

### Para mayor tráfico
- Múltiples instancias PM2
- Load balancer
- CDN para archivos estáticos
- Base de datos para cache

## 📄 Licencia

MIT License - Ver archivo LICENSE para más detalles.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una rama para tu feature
3. Commit tus cambios
4. Push a la rama
5. Abre un Pull Request

## 📞 Soporte

Para soporte técnico:

- 📧 Email: soporte@ejemplo.com
- 🐛 Issues: [GitHub Issues](https://github.com/usuario/yt-downloader/issues)
- 📖 Documentación: Este README

---

**¡Disfruta descargando videos de YouTube! 🎉**
