const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const path = require('path');
const fs = require('fs-extra');

// Importar rutas
const apiRoutes = require('./src/routes/api');
const webRoutes = require('./src/routes/web');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware de seguridad
app.use(helmet({
  contentSecurityPolicy: false // Permitir recursos inline para la interfaz
}));

// Middleware CORS
app.use(cors());

// Middleware de logging
app.use(morgan('combined'));

// Middleware para parsing
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Servir archivos estáticos
app.use(`/static`, express.static(path.join(__dirname, 'public')));

// Crear carpetas necesarias
const createDirectories = async () => {
  const dirs = ['downloads', 'downloads/audio', 'downloads/video', 'public'];
  
  for (const dir of dirs) {
    try {
      await fs.ensureDir(path.join(__dirname, dir));
      console.log(`✓ Directorio creado/verificado: ${dir}`);
    } catch (error) {
      console.error(`Error creando directorio ${dir}:`, error);
    }
  }
};

// Rutas
app.use(`/api`, apiRoutes);
app.use(`/`, webRoutes);

// Endpoint de prueba
app.get(`/health`, (req, res) => {
  res.json({
    status: 'OK',
    message: 'YTDownloader server funcionando correctamente',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    basePath: '/'
  });
});

// Manejo de errores global
app.use((error, req, res, next) => {
  console.error('Error:', error);
  res.status(500).json({
    error: 'Error interno del servidor',
    message: process.env.NODE_ENV === 'development' ? error.message : 'Algo salió mal'
  });
});

// Manejo de rutas no encontradas
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Ruta no encontrada',
    message: 'La ruta solicitada no existe'
  });
});

// Inicializar servidor
const startServer = async () => {
  try {
    // Crear directorios necesarios
    await createDirectories();
    
    // Iniciar servidor
    app.listen(PORT, () => {
      console.log('🚀 YTDownloader Server iniciado');
      console.log(`📡 Puerto: ${PORT}`);
      console.log(`🌐 URL: http://localhost:${PORT}`);
      console.log(`💚 Health check: http://localhost:${PORT}/health`);
      console.log(`📱 Interfaz web: http://localhost:${PORT}/`);
      
      if (process.env.NODE_ENV === 'production') {
        console.log('🏭 Modo producción activado');
      } else {
        console.log('🔧 Modo desarrollo activado');
      }
    });
  } catch (error) {
    console.error('❌ Error iniciando servidor:', error);
    process.exit(1);
  }
};

// Manejo de señales para cierre graceful
process.on('SIGTERM', () => {
  console.log('🛑 Recibida señal SIGTERM, cerrando servidor...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Recibida señal SIGINT, cerrando servidor...');
  process.exit(0);
});

// Iniciar servidor
startServer();
