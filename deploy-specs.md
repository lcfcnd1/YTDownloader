# Especificaciones de la aplicación

## Tipo de app
- Node.js con Express  
- Python con Flask

## Puertos por defecto
- Node: 3000
- Flask: 5000

## Producción
- Node.js: PM2
- Flask: Gunicorn + PM2
- Nginx como proxy inverso
- **Dominio / IP de la VPS:** sqsoft.top

## Archivos principales
- Node: server.js, package.json, ecosystem.config.js
- Flask: app.py, requirements.txt, run.sh

## Endpoints de prueba
- `/` debe devolver un mensaje indicando que el servidor funciona

## Estructura de carpetas
- Node: src/, routes/, public/, etc.
- Flask: src/, templates/, static/

## Extras
- README.md con instrucciones de deploy
- Comentarios indicando cómo iniciar la app en producción
- Código limpio y optimizado para tráfico bajo (solo 4 usuarios)

## Reglas para start.sh / run.sh y configuración de Nginx

Al ejecutar el script de inicio (`start.sh` para Node o `run.sh` para Flask) en modo producción:

1. Debe crear automáticamente el archivo de configuración de Nginx para la app, usando como `server_name` la IP de la VPS: sqsoft.top
2. Debe activar el sitio con un enlace simbólico en `/etc/nginx/sites-enabled/`.
3. Debe verificar la configuración con `nginx -t` y recargar Nginx (`systemctl reload nginx`).
4. Todas las acciones que requieran privilegios deben ejecutarse con `sudo` solo si es necesario.
5. Debe imprimir mensajes claros indicando que Nginx se configuró correctamente.
6. No debe sobrescribir configuraciones existentes si ya existe un archivo con el mismo nombre.
7. El script debe:
   - Crear carpetas necesarias si se necesitan generar
   - Instalar dependencias (npm install para Node; pip install -r requirements.txt para Flask)
   - Iniciar la app en modo desarrollo o producción según el parámetro
8. Debe estar preparado para múltiples apps en la misma VPS, permitiendo definir rutas distintas en Nginx (`/app1`, `/app2`, `/flask`) y redirigiendo a diferentes puertos según cada proyecto.
9. Para Flask, el script debe usar Gunicorn como servidor de producción, gestionado por PM2.
