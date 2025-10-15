const { exec, spawn } = require('child_process');
const { promisify } = require('util');
const fs = require('fs-extra');
const path = require('path');

const execAsync = promisify(exec);

class YtDlpHelper {
    constructor() {
        this.ytdlpPath = 'yt-dlp'; // Asumimos que yt-dlp está en PATH
        this.userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
        this.defaultArgs = [
            '-4',
            '--user-agent', this.userAgent
        ];
    }

    /**
     * Verificar si yt-dlp está instalado
     */
    async checkInstallation() {
        try {
            const { stdout } = await execAsync(`${this.ytdlpPath} --version`);
            return stdout.trim();
        } catch (error) {
            throw new Error('yt-dlp no está instalado o no está en PATH');
        }
    }

    /**
     * Obtener información de un video
     */
    async getVideoInfo(url) {
        try {
            const command = `${this.ytdlpPath} -4 --user-agent "${this.userAgent}" --dump-json --no-download "${url}"`;
            const { stdout } = await execAsync(command);
            
            const info = JSON.parse(stdout);
            return {
                id: info.id,
                title: info.title,
                description: info.description,
                uploader: info.uploader,
                thumbnail: info.thumbnail,
                duration: info.duration,
                view_count: info.view_count,
                upload_date: info.upload_date,
                _type: 'video'
            };
        } catch (error) {
            throw new Error(`Error obteniendo información del video: ${error.message}`);
        }
    }

    /**
     * Obtener título de un video
     */
    async getTitle(url) {
        try {
            const command = `${this.ytdlpPath} -4 --user-agent "${this.userAgent}" --get-title --no-download "${url}"`;
            const { stdout } = await execAsync(command);
            return stdout.trim();
        } catch (error) {
            throw new Error(`Error obteniendo título: ${error.message}`);
        }
    }

    /**
     * Descargar audio en formato MP3
     */
    async downloadAudio(url, outputPath, onProgress = null) {
        return new Promise((resolve, reject) => {
            const args = [
                ...this.defaultArgs,
                '--extract-audio',
                '--audio-format', 'mp3',
                '--audio-quality', '0', // Mejor calidad
                '--output', outputPath,
                url
            ];

            console.log(`Ejecutando: ${this.ytdlpPath} ${args.join(' ')}`);

            const process = spawn(this.ytdlpPath, args);

            let stderr = '';
            let progressData = '';

            process.stdout.on('data', (data) => {
                const output = data.toString();
                console.log('stdout:', output);
                
                // Extraer progreso si hay callback
                if (onProgress && output.includes('%')) {
                    const match = output.match(/(\d+(?:\.\d+)?)%/);
                    if (match) {
                        const percent = parseFloat(match[1]);
                        onProgress({ percent });
                    }
                }
            });

            process.stderr.on('data', (data) => {
                stderr += data.toString();
                const output = data.toString();
                console.log('stderr:', output);
                
                // Extraer progreso del stderr también
                if (onProgress && output.includes('%')) {
                    const match = output.match(/(\d+(?:\.\d+)?)%/);
                    if (match) {
                        const percent = parseFloat(match[1]);
                        onProgress({ percent });
                    }
                }
            });

            process.on('close', (code) => {
                if (code === 0) {
                    console.log('Descarga de audio completada exitosamente');
                    resolve(outputPath);
                } else {
                    console.error('Error en descarga de audio:', stderr);
                    reject(new Error(`yt-dlp falló con código ${code}: ${stderr}`));
                }
            });

            process.on('error', (error) => {
                console.error('Error ejecutando yt-dlp:', error);
                reject(error);
            });
        });
    }

    /**
     * Descargar video con formato dinámico (consulta formatos disponibles)
     */
    async downloadVideoDynamic(url, outputPath, preferredQuality = '1080p', onProgress = null) {
        try {
            // Siempre combinar mejor video + mejor audio y remux a MP4
            console.log('🎬 Forzando combinación bestvideo+bestaudio (MP4)...');
            return await this.downloadVideoWithSeparateAudio(url, outputPath, preferredQuality, onProgress);
        } catch (error) {
            console.log('⚠️ Error combinando video/audio, usando fallback a best...');
            return await this.downloadVideo(url, outputPath, 'best', onProgress);
        }
    }

    /**
     * Descargar video combinando video y audio por separado
     */
    async downloadVideoWithSeparateAudio(url, outputPath, preferredQuality = '1080p', onProgress = null) {
        return new Promise((resolve, reject) => {
            // Usar formato que combine automáticamente el mejor video con el mejor audio
            const formatString = `bestvideo[height<=${preferredQuality.replace('p', '')}]+bestaudio/best[height<=${preferredQuality.replace('p', '')}]/best`;
            
            const args = [
                ...this.defaultArgs,
                '--format', formatString,
                '--merge-output-format', 'mp4',
                '--output', outputPath,
                url
            ];

            console.log(`Ejecutando combinación: ${this.ytdlpPath} ${args.join(' ')}`);

            const process = spawn(this.ytdlpPath, args);

            let stderr = '';

            process.stdout.on('data', (data) => {
                const output = data.toString();
                console.log('stdout:', output);
                
                // Extraer progreso si hay callback
                if (onProgress && output.includes('%')) {
                    const match = output.match(/(\d+(?:\.\d+)?)%/);
                    if (match) {
                        const percent = parseFloat(match[1]);
                        onProgress({ percent });
                    }
                }
            });

            process.stderr.on('data', (data) => {
                stderr += data.toString();
                const output = data.toString();
                console.log('stderr:', output);
                
                // Extraer progreso del stderr también
                if (onProgress && output.includes('%')) {
                    const match = output.match(/(\d+(?:\.\d+)?)%/);
                    if (match) {
                        const percent = parseFloat(match[1]);
                        onProgress({ percent });
                    }
                }
            });

            process.on('close', (code) => {
                if (code === 0) {
                    console.log('Descarga de video con audio combinado completada exitosamente');
                    resolve(outputPath);
                } else {
                    console.error('Error en descarga de video con audio:', stderr);
                    reject(new Error(`yt-dlp falló con código ${code}: ${stderr}`));
                }
            });

            process.on('error', (error) => {
                console.error('Error ejecutando yt-dlp:', error);
                reject(error);
            });
        });
    }

    /**
     * Descargar video en formato MP4 con formato específico
     */
    async downloadVideo(url, outputPath, formatId = 'best', onProgress = null) {
        return new Promise((resolve, reject) => {
            const args = [
                ...this.defaultArgs,
                '--format', formatId,
                '--merge-output-format', 'mp4',
                '--output', outputPath,
                url
            ];

            console.log(`Ejecutando: ${this.ytdlpPath} ${args.join(' ')}`);

            const process = spawn(this.ytdlpPath, args);

            let stderr = '';

            process.stdout.on('data', (data) => {
                const output = data.toString();
                console.log('stdout:', output);
                
                // Extraer progreso si hay callback
                if (onProgress && output.includes('%')) {
                    const match = output.match(/(\d+(?:\.\d+)?)%/);
                    if (match) {
                        const percent = parseFloat(match[1]);
                        onProgress({ percent });
                    }
                }
            });

            process.stderr.on('data', (data) => {
                stderr += data.toString();
                const output = data.toString();
                console.log('stderr:', output);
                
                // Extraer progreso del stderr también
                if (onProgress && output.includes('%')) {
                    const match = output.match(/(\d+(?:\.\d+)?)%/);
                    if (match) {
                        const percent = parseFloat(match[1]);
                        onProgress({ percent });
                    }
                }
            });

            process.on('close', (code) => {
                if (code === 0) {
                    console.log('Descarga de video completada exitosamente');
                    resolve(outputPath);
                } else {
                    console.error('Error en descarga de video:', stderr);
                    reject(new Error(`yt-dlp falló con código ${code}: ${stderr}`));
                }
            });

            process.on('error', (error) => {
                console.error('Error ejecutando yt-dlp:', error);
                reject(error);
            });
        });
    }

    /**
     * Obtener formatos disponibles para un video
     */
    async getAvailableFormats(url) {
        try {
            const command = `${this.ytdlpPath} -4 --user-agent "${this.userAgent}" --list-formats --no-download "${url}"`;
            const { stdout } = await execAsync(command);
            
            // Parsear formatos del output
            const lines = stdout.split('\n').filter(line => line.trim());
            const formats = [];
            
            console.log('📋 Formatos disponibles:');
            
            for (const line of lines) {
                // Buscar líneas que contengan información de formato
                // Patrones más flexibles para diferentes formatos de output
                const patterns = [
                    /^(\d+)\s+(\d+x\d+|\d+p|\d+k|\d+)\s+(\w+)\s+(.+)$/,
                    /^(\d+)\s+(\d+x\d+|\d+p|\d+k)\s+(.+)$/,
                    /^(\d+)\s+(.+)$/
                ];
                
                let match = null;
                for (const pattern of patterns) {
                    match = line.match(pattern);
                    if (match) break;
                }
                
                if (match) {
                    const formatId = match[1];
                    const resolution = match[2] || 'unknown';
                    const ext = match[3] || 'mp4';
                    const info = match[4] || match[3] || match[2] || '';
                    
                    // Incluir todos los formatos (video, audio, y combinados)
                    if (info.includes('video') || info.includes('audio') || info.includes('mp4') || 
                        info.includes('webm') || info.includes('m4a') || info.includes('mp3') ||
                        info.includes('video+audio') || info.includes('audio+video')) {
                        
                        const format = {
                            id: formatId,
                            resolution: resolution,
                            ext: ext,
                            info: info,
                            hasAudio: info.includes('audio'),
                            hasVideo: info.includes('video'),
                            isVideoOnly: info.includes('video') && !info.includes('audio'),
                            isAudioOnly: info.includes('audio') && !info.includes('video'),
                            isCombined: info.includes('video') && info.includes('audio')
                        };
                        
                        formats.push(format);
                        
                        // Mostrar con iconos para mejor identificación
                        let icon = '📄';
                        if (format.isCombined) icon = '🎬';
                        else if (format.isVideoOnly) icon = '📹';
                        else if (format.isAudioOnly) icon = '🎵';
                        
                        console.log(`  ${icon} ${formatId}: ${resolution} - ${info}`);
                    }
                }
            }
            
            console.log(`✅ Encontrados ${formats.length} formatos de video`);
            return formats;
        } catch (error) {
            throw new Error(`Error obteniendo formatos: ${error.message}`);
        }
    }

    /**
     * Seleccionar el mejor formato disponible
     */
    selectBestFormat(formats, preferredQuality = '1080p') {
        if (formats.length === 0) {
            console.log('No hay formatos disponibles, usando formato por defecto');
            return 'best';
        }

        // Función para extraer altura de resolución
        const getHeight = (resolution) => {
            if (!resolution || resolution === 'unknown') return 0;
            
            if (resolution.includes('x')) {
                const parts = resolution.split('x');
                return parts.length > 1 ? parseInt(parts[1]) : 0;
            }
            
            if (resolution.includes('p')) {
                return parseInt(resolution.replace('p', ''));
            }
            
            if (resolution.includes('k')) {
                return parseInt(resolution.replace('k', '')) * 1000;
            }
            
            return 0;
        };

        // Separar formatos con y sin audio
        const formatsWithAudio = formats.filter(f => f.isCombined || f.hasAudio);
        const formatsVideoOnly = formats.filter(f => f.isVideoOnly);
        
        console.log(`📊 ${formatsWithAudio.length} formatos con audio, ${formatsVideoOnly.length} solo video`);
        
        // Ordenar formatos con audio por calidad (resolución) descendente
        const sortedFormatsWithAudio = formatsWithAudio.sort((a, b) => {
            const heightA = getHeight(a.resolution);
            const heightB = getHeight(b.resolution);
            return heightB - heightA;
        });
        
        // Ordenar formatos solo video por calidad (resolución) descendente
        const sortedFormatsVideoOnly = formatsVideoOnly.sort((a, b) => {
            const heightA = getHeight(a.resolution);
            const heightB = getHeight(b.resolution);
            return heightB - heightA;
        });
        
        // Combinar: primero formatos con audio, luego solo video
        const sortedFormats = [...sortedFormatsWithAudio, ...sortedFormatsVideoOnly];
        
        console.log('🎯 Formatos ordenados por calidad:');
        sortedFormats.forEach((format, index) => {
            const height = getHeight(format.resolution);
            let icon = '📄';
            if (format.isCombined) icon = '🎬';
            else if (format.isVideoOnly) icon = '📹';
            else if (format.isAudioOnly) icon = '🎵';
            
            console.log(`  ${icon} ${index + 1}. ${format.id}: ${format.resolution} (${height}p) - ${format.info}`);
        });
        
        // Buscar el formato que mejor se adapte a la calidad preferida
        const preferredHeight = parseInt(preferredQuality.replace('p', ''));
        
        for (const format of sortedFormats) {
            const formatHeight = getHeight(format.resolution);
            
            if (formatHeight <= preferredHeight && formatHeight > 0) {
                console.log(`✅ Seleccionado formato: ${format.id} (${format.resolution}) - ${format.info}`);
                return format.id;
            }
        }
        
        // Si no encuentra uno adecuado, usar el mejor disponible
        if (sortedFormats.length > 0) {
            const bestFormat = sortedFormats[0];
            console.log(`⚠️ Usando mejor formato disponible: ${bestFormat.id} (${bestFormat.resolution}) - ${bestFormat.info}`);
            return bestFormat.id;
        }
        
        // Fallback: usar formato por defecto
        console.log('❌ Usando formato por defecto: best');
        return 'best';
    }

    /**
     * Obtener thumbnails de un video
     */
    async getThumbnails(url) {
        try {
            const command = `${this.ytdlpPath} -4 --user-agent "${this.userAgent}" --list-thumbnails --no-download "${url}"`;
            const { stdout } = await execAsync(command);
            
            // Parsear thumbnails del output
            const lines = stdout.split('\n').filter(line => line.trim());
            const thumbnails = lines.map(line => {
                const match = line.match(/^(\d+)\s+(.+)$/);
                if (match) {
                    return {
                        id: match[1],
                        url: match[2]
                    };
                }
                return null;
            }).filter(Boolean);

            return thumbnails;
        } catch (error) {
            throw new Error(`Error obteniendo thumbnails: ${error.message}`);
        }
    }

    /**
     * Limpiar archivo después de un tiempo determinado
     */
    async cleanupFile(filePath, delayMs = 300000) { // 5 minutos por defecto
        return new Promise((resolve) => {
            setTimeout(async () => {
                try {
                    if (await fs.pathExists(filePath)) {
                        await fs.unlink(filePath);
                        console.log(`🗑️ Archivo eliminado automáticamente: ${filePath}`);
                    }
                    resolve();
                } catch (error) {
                    console.error('Error eliminando archivo:', error);
                    resolve(); // No fallar si no se puede eliminar
                }
            }, delayMs);
        });
    }
}

module.exports = new YtDlpHelper();
