const express = require('express');
const router = express.Router();
const youtubesearchapi = require('youtube-search-api');
const path = require('path');
const fs = require('fs-extra');
const ytdlp = require('../utils/ytdlp');

// Endpoint para buscar videos
router.get('/search', async (req, res) => {
  try {
    const { q } = req.query;
    const limit = Math.max(1, Math.min(parseInt(req.query.limit || '12', 10), 50));
    const pageToken = req.query.pageToken || null;
    let pageContext = null;
    if (req.query.pageContext) {
      try {
        pageContext = JSON.parse(req.query.pageContext);
      } catch (_) {
        pageContext = null;
      }
    }
    
    if (!q || q.trim().length === 0) {
      return res.status(400).json({
        error: 'Parámetro de búsqueda requerido',
        message: 'Debe proporcionar un término de búsqueda válido'
      });
    }

    console.log(`🔍 Buscando: "${q}" (limit=${limit}, pageToken=${!!pageToken})`);

    let searchResults;
    
    if (pageToken) {
      // Usar NextPage para cargar más resultados (requiere token y contexto)
      searchResults = await youtubesearchapi.NextPage({ nextPageToken: pageToken, nextPageContext: pageContext }, false, limit);
    } else {
      // Primera búsqueda
      searchResults = await youtubesearchapi.GetListByKeyword(q, false, limit);
    }

    const items = searchResults?.items || [];
    const videos = items.map(item => ({
      id: item.id,
      title: item.title,
      thumbnail: item.thumbnail?.thumbnails?.[0]?.url || item.thumbnail?.url,
      channel: item.channelTitle,
      duration: item.length?.simpleText || 'N/A',
      views: item.viewCount?.simpleText || 'N/A',
      published: item.publishedTimeText?.simpleText || 'N/A'
    })).filter(v => v.id);

    const nextPageToken = searchResults?.nextPage?.nextPageToken || null;
    const nextPageContext = searchResults?.nextPage?.nextPageContext || null;
    const hasMore = !!nextPageToken;
    
    console.log(`✓ Retornando ${videos.length} videos (hasMore=${hasMore})`);

    res.json({
      success: true,
      query: q,
      results: videos,
      pageToken: nextPageToken,
      pageContext: nextPageContext,
      limit,
      hasMore
    });

  } catch (error) {
    console.error('Error en búsqueda:', error);
    res.status(500).json({
      error: 'Error en la búsqueda',
      message: 'Ocurrió un error al buscar videos'
    });
  }
});

// Endpoint para obtener información de un video
router.get('/video/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    
    if (!videoId) {
      return res.status(400).json({
        error: 'ID de video requerido'
      });
    }

    console.log(`📹 Obteniendo info del video: ${videoId}`);
    
    // Construir URL completa
    const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;
    
    // Obtener información del video usando yt-dlp directamente
    const videoInfo = await ytdlp.getVideoInfo(videoUrl);
    
    if (videoInfo._type !== 'video') {
      return res.status(400).json({
        error: 'No es un video válido'
      });
    }
    
    const videoData = {
      id: videoId,
      title: videoInfo.title,
      description: videoInfo.description,
      author: videoInfo.uploader,
      thumbnail: videoInfo.thumbnail,
      duration: videoInfo.duration,
      viewCount: videoInfo.view_count,
      uploadDate: videoInfo.upload_date
    };

    res.json({
      success: true,
      video: videoData
    });

  } catch (error) {
    console.error('Error obteniendo info del video:', error);
    res.status(500).json({
      error: 'Error obteniendo información del video',
      message: 'El video podría no existir o no estar disponible'
    });
  }
});

// Endpoint para descargar audio MP3
router.get('/download/audio/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    const { title } = req.query;
    
    if (!videoId) {
      return res.status(400).json({
        error: 'ID de video requerido'
      });
    }

    console.log(`🎵 Descargando audio: ${videoId}`);
    
    // Construir URL completa
    const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;
    
    // Obtener información del video para el título
    let videoTitle = title;
    if (!videoTitle) {
      try {
        videoTitle = await ytdlp.getTitle(videoUrl);
      } catch (error) {
        console.log('No se pudo obtener título, usando ID:', error.message);
        videoTitle = videoId;
      }
    }

    const safeTitle = videoTitle.replace(/[^\w\s-]/g, '').trim();
    const audioPath = path.join(__dirname, '../../downloads/audio', `${safeTitle}.%(ext)s`);
    const finalAudioPath = path.join(__dirname, '../../downloads/audio', `${safeTitle}.mp3`);
    
    // Verificar si ya existe
    if (await fs.pathExists(finalAudioPath)) {
      return res.download(finalAudioPath, `${safeTitle}.mp3`);
    }

    console.log(`Iniciando descarga de audio para: ${safeTitle}`);

    // Descargar audio usando yt-dlp directamente
    const result = await ytdlp.downloadAudio(videoUrl, audioPath, (progress) => {
      console.log(`Progreso descarga: ${progress.percent || 0}%`);
    });

    console.log(`✓ Audio descargado: ${safeTitle}.mp3`);
    
    // Verificar que el archivo se creó correctamente
    if (await fs.pathExists(finalAudioPath)) {
      // Programar limpieza automática del archivo después de 5 minutos
      ytdlp.cleanupFile(finalAudioPath, 300000); // 5 minutos
      
      // Enviar archivo
      res.download(finalAudioPath, `${safeTitle}.mp3`, (err) => {
        if (err) {
          console.error('Error enviando archivo:', err);
        }
      });
    } else {
      throw new Error('El archivo no se creó correctamente');
    }

  } catch (error) {
    console.error('Error descargando audio:', error);
    
    // Mensajes de error más específicos
    let errorMessage = 'No se pudo descargar el audio del video';
    if (error.message.includes('Video unavailable')) {
      errorMessage = 'El video no está disponible o es privado.';
    } else if (error.message.includes('Sign in to confirm your age')) {
      errorMessage = 'El video tiene restricciones de edad.';
    } else if (error.message.includes('Private video')) {
      errorMessage = 'El video es privado y no se puede descargar.';
    } else if (error.message.includes('This video is not available')) {
      errorMessage = 'Este video no está disponible en tu región.';
    }
    
    res.status(500).json({
      error: 'Error descargando audio',
      message: errorMessage
    });
  }
});

// Endpoint para descargar video MP4
router.get('/download/video/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    const { quality = '1080p', title } = req.query;
    
    if (!videoId) {
      return res.status(400).json({
        error: 'ID de video requerido'
      });
    }

    console.log(`🎬 Descargando video: ${videoId}`);
    
    // Construir URL completa
    const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;
    
    // Obtener información del video para el título
    let videoTitle = title;
    if (!videoTitle) {
      try {
        videoTitle = await ytdlp.getTitle(videoUrl);
      } catch (error) {
        console.log('No se pudo obtener título, usando ID:', error.message);
        videoTitle = videoId;
      }
    }

    const safeTitle = videoTitle.replace(/[^\w\s-]/g, '').trim();
    const videoPath = path.join(__dirname, '../../downloads/video', `${safeTitle}.%(ext)s`);
    const finalVideoPath = path.join(__dirname, '../../downloads/video', `${safeTitle}.mp4`);
    
    // Verificar si ya existe
    if (await fs.pathExists(finalVideoPath)) {
      return res.download(finalVideoPath, `${safeTitle}.mp4`);
    }

    console.log(`Iniciando descarga de video para: ${safeTitle}`);

    // Mapear calidad de entrada
    let preferredQuality = quality;
    if (quality === 'highest') {
      preferredQuality = '1080p';
    }

    // Descargar video usando formato dinámico (consulta formatos disponibles)
    const result = await ytdlp.downloadVideoDynamic(videoUrl, videoPath, preferredQuality, (progress) => {
      console.log(`Progreso descarga: ${progress.percent || 0}%`);
    });

    console.log(`✓ Video descargado: ${safeTitle}.mp4`);
    
    // Verificar que el archivo se creó correctamente
    if (await fs.pathExists(finalVideoPath)) {
      // Programar limpieza automática del archivo después de 10 minutos (videos son más grandes)
      ytdlp.cleanupFile(finalVideoPath, 600000); // 10 minutos
      
      // Enviar archivo
      res.download(finalVideoPath, `${safeTitle}.mp4`, (err) => {
        if (err) {
          console.error('Error enviando archivo:', err);
        }
      });
    } else {
      throw new Error('El archivo no se creó correctamente');
    }

  } catch (error) {
    console.error('Error descargando video:', error);
    
    // Mensajes de error más específicos
    let errorMessage = 'No se pudo descargar el video';
    if (error.message.includes('Video unavailable')) {
      errorMessage = 'El video no está disponible o es privado.';
    } else if (error.message.includes('Sign in to confirm your age')) {
      errorMessage = 'El video tiene restricciones de edad.';
    } else if (error.message.includes('Private video')) {
      errorMessage = 'El video es privado y no se puede descargar.';
    } else if (error.message.includes('This video is not available')) {
      errorMessage = 'Este video no está disponible en tu región.';
    }
    
    res.status(500).json({
      error: 'Error descargando video',
      message: errorMessage
    });
  }
});

// Endpoint para obtener formatos disponibles de un video
router.get('/formats/:videoId', async (req, res) => {
  try {
    const { videoId } = req.params;
    
    if (!videoId) {
      return res.status(400).json({
        error: 'ID de video requerido'
      });
    }

    console.log(`📋 Obteniendo formatos para: ${videoId}`);
    
    // Construir URL completa
    const videoUrl = `https://www.youtube.com/watch?v=${videoId}`;
    
    // Obtener formatos disponibles
    const formats = await ytdlp.getAvailableFormats(videoUrl);
    
    res.json({
      success: true,
      videoId: videoId,
      formats: formats,
      total: formats.length
    });

  } catch (error) {
    console.error('Error obteniendo formatos:', error);
    res.status(500).json({
      error: 'Error obteniendo formatos',
      message: 'No se pudieron obtener los formatos del video'
    });
  }
});

// Endpoint para limpiar archivos descargados
router.delete('/cleanup', async (req, res) => {
  try {
    const { type = 'all' } = req.query;
    
    const audioDir = path.join(__dirname, '../../downloads/audio');
    const videoDir = path.join(__dirname, '../../downloads/video');
    
    let deletedFiles = 0;
    
    if (type === 'all' || type === 'audio') {
      const audioFiles = await fs.readdir(audioDir);
      for (const file of audioFiles) {
        if (file !== '.gitkeep') {
          await fs.unlink(path.join(audioDir, file));
          deletedFiles++;
        }
      }
    }
    
    if (type === 'all' || type === 'video') {
      const videoFiles = await fs.readdir(videoDir);
      for (const file of videoFiles) {
        if (file !== '.gitkeep') {
          await fs.unlink(path.join(videoDir, file));
          deletedFiles++;
        }
      }
    }
    
    console.log(`🗑️ Eliminados ${deletedFiles} archivos`);
    
    res.json({
      success: true,
      message: `Se eliminaron ${deletedFiles} archivos`,
      deletedFiles
    });

  } catch (error) {
    console.error('Error limpiando archivos:', error);
    res.status(500).json({
      error: 'Error limpiando archivos',
      message: 'No se pudieron eliminar los archivos'
    });
  }
});

module.exports = router;