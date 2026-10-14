// js/compressor.js
// فشرده‌سازی خودکار عکس و فیلم قبل از آپلود

const MAX_UPLOAD_MB = 45; // کمتر از ۵۰ مگابایت Supabase

// ═══════════════════════════════════════════
//  فشرده‌سازی عکس با Canvas
// ═══════════════════════════════════════════
export async function compressImage(file, opts = {}) {
  const {
    maxDim = 1920,      // حداکثر بُعد
    quality = 0.82,     // کیفیت JPEG
    minQuality = 0.5
  } = opts;

  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);

    img.onload = async () => {
      URL.revokeObjectURL(url);

      let { width, height } = img;

      // تغییر اندازه اگر بزرگ‌تر از حد مجاز بود
      if (width > maxDim || height > maxDim) {
        if (width > height) {
          height = Math.round(height * maxDim / width);
          width = maxDim;
        } else {
          width = Math.round(width * maxDim / height);
          height = maxDim;
        }
      }

      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d');
      ctx.drawImage(img, 0, 0, width, height);

      // تلاش با کیفیت‌های پایین‌تر اگر خیلی بزرگ بود
      let q = quality;
      let blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', q));

      while (blob && blob.size > MAX_UPLOAD_MB * 1024 * 1024 && q > minQuality) {
        q -= 0.1;
        blob = await new Promise(r => canvas.toBlob(r, 'image/jpeg', q));
      }

      if (!blob) return reject(new Error('فشرده‌سازی عکس شکست خورد'));

      const ext = '.jpg';
      const baseName = file.name.replace(/\.[^.]+$/, '') || 'image';
      const newFile = new File([blob], baseName + ext, {
        type: 'image/jpeg',
        lastModified: Date.now()
      });

      resolve({
        file: newFile,
        originalSize: file.size,
        newSize: newFile.size
      });
    };

    img.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error('خطا در خواندن عکس'));
    };

    img.src = url;
  });
}

// ═══════════════════════════════════════════
//  فشرده‌سازی فیلم با FFmpeg.wasm
// ═══════════════════════════════════════════
let ffmpegInstance = null;
let ffmpegLoading = null;

async function loadFFmpeg() {
  if (ffmpegInstance) return ffmpegInstance;
  if (ffmpegLoading) return ffmpegLoading;

  ffmpegLoading = (async () => {
    // تلاش چند CDN
    const CDNS = [
      {
        ffmpeg: 'https://unpkg.com/@ffmpeg/ffmpeg@0.12.10/dist/umd/ffmpeg.js',
        util:   'https://unpkg.com/@ffmpeg/util@0.12.1/dist/umd/index.js',
        core:   'https://unpkg.com/@ffmpeg/core@0.12.6/dist/umd/ffmpeg-core.js',
        wasm:   'https://unpkg.com/@ffmpeg/core@0.12.6/dist/umd/ffmpeg-core.wasm'
      },
      {
        ffmpeg: 'https://cdn.jsdelivr.net/npm/@ffmpeg/ffmpeg@0.12.10/dist/umd/ffmpeg.js',
        util:   'https://cdn.jsdelivr.net/npm/@ffmpeg/util@0.12.1/dist/umd/index.js',
        core:   'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.6/dist/umd/ffmpeg-core.js',
        wasm:   'https://cdn.jsdelivr.net/npm/@ffmpeg/core@0.12.6/dist/umd/ffmpeg-core.wasm'
      }
    ];

    let lastError = null;
    for (const cdn of CDNS) {
      try {
        await loadScript(cdn.ffmpeg);
        await loadScript(cdn.util);

        const { FFmpeg } = window.FFmpegWASM;
        const ffmpeg = new FFmpeg();

        await ffmpeg.load({
          coreURL: cdn.core,
          wasmURL: cdn.wasm
        });

        return ffmpeg;
      } catch (e) {
        console.warn('FFmpeg CDN failed:', cdn.ffmpeg, e);
        lastError = e;
      }
    }
    throw new Error('بارگذاری FFmpeg شکست خورد: ' + (lastError?.message || 'نامشخص'));
  })();

  ffmpegInstance = await ffmpegLoading;
  return ffmpegInstance;
}

function loadScript(src) {
  return new Promise((resolve, reject) => {
    if (document.querySelector(`script[src="${src}"]`)) return resolve();
    const s = document.createElement('script');
    s.src = src;
    s.onload = resolve;
    s.onerror = () => reject(new Error('Failed to load: ' + src));
    document.head.appendChild(s);
  });
}

export async function compressVideo(file, onProgress) {
  const ffmpeg = await loadFFmpeg();
  const { fetchFile } = window.FFmpegUtil;

  // اگر بیش از حد بزرگ بود، کیفیت را کمتر کن
  const sizeMB = file.size / 1024 / 1024;
  let crf = 28;          // کیفیت پایین‌تر = فشرده‌تر (18-32)
  let maxDim = 1280;     // حداکثر عرض

  if (sizeMB > 100) {
    crf = 32;
    maxDim = 960;
  } else if (sizeMB > 50) {
    crf = 30;
    maxDim = 1120;
  }

  const inputName = 'input_' + Date.now() + '.mp4';
  const outputName = 'output_' + Date.now() + '.mp4';

  if (onProgress) {
    ffmpeg.on('progress', ({ progress }) => {
      onProgress(Math.min(100, Math.round(progress * 100)));
    });
  }

  await ffmpeg.writeFile(inputName, await fetchFile(file));

  // فشرده‌سازی
  await ffmpeg.exec([
    '-i', inputName,
    '-vf', `scale='min(${maxDim},iw)':-2`,
    '-c:v', 'libx264',
    '-crf', String(crf),
    '-preset', 'fast',
    '-c:a', 'aac',
    '-b:a', '128k',
    '-movflags', '+faststart',
    outputName
  ]);

  const data = await ffmpeg.readFile(outputName);
  const blob = new Blob([data.buffer], { type: 'video/mp4' });

  // پاکسازی
  try { await ffmpeg.deleteFile(inputName); } catch(e) {}
  try { await ffmpeg.deleteFile(outputName); } catch(e) {}

  const baseName = file.name.replace(/\.[^.]+$/, '') || 'video';
  const newFile = new File([blob], baseName + '.mp4', {
    type: 'video/mp4',
    lastModified: Date.now()
  });

  return {
    file: newFile,
    originalSize: file.size,
    newSize: newFile.size
  };
}

// ═══════════════════════════════════════════
//  تابع اصلی فشرده‌سازی
// ═══════════════════════════════════════════
export async function compressFile(file, onStatus, onProgress) {
  const sizeMB = file.size / 1024 / 1024;

  // عکس → فشرده کن
  if (file.type.startsWith('image/')) {
    // اگر عکس زیر ۵۰۰ کیلوبایت است، دست نزن
    if (sizeMB < 0.5) {
      return { file, compressed: false, originalSize: file.size, newSize: file.size };
    }
    if (onStatus) onStatus('در حال فشرده‌سازی عکس...');
    const result = await compressImage(file);
    return {
      file: result.file,
      compressed: true,
      originalSize: result.originalSize,
      newSize: result.newSize
    };
  }

  // فیلم → فشرده کن (اگر بزرگ بود)
  if (file.type.startsWith('video/')) {
    if (sizeMB < 20) {
      // زیر ۲۰ مگابایت، دست نزن
      return { file, compressed: false, originalSize: file.size, newSize: file.size };
    }
    if (onStatus) onStatus('در حال آماده‌سازی فشرده‌ساز فیلم...');
    try {
      const result = await compressVideo(file, (p) => {
        if (onProgress) onProgress(p);
      });
      return {
        file: result.file,
        compressed: true,
        originalSize: result.originalSize,
        newSize: result.newSize
      };
    } catch (e) {
      console.warn('Video compression failed:', e);
      // اگر شکست خورد، چک کن حجم اصلی قابل قبول است
      if (sizeMB > MAX_UPLOAD_MB) {
        throw new Error(`فشرده‌سازی فیلم ممکن نشد. حجم فایل ${sizeMB.toFixed(1)} مگابایت است که بیش از حد مجاز (${MAX_UPLOAD_MB} مگابایت) می‌باشد.`);
      }
      if (onStatus) onStatus('فشرده‌سازی فیلم ممکن نشد — ارسال فایل اصلی...');
      return { file, compressed: false, originalSize: file.size, newSize: file.size };
    }
  }

  // فایل دیگر → چک حجم
  if (sizeMB > MAX_UPLOAD_MB) {
    throw new Error(`حجم فایل ${sizeMB.toFixed(1)} مگابایت است. حداکثر مجاز: ${MAX_UPLOAD_MB} مگابایت.`);
  }

  return { file, compressed: false, originalSize: file.size, newSize: file.size };
}

export function formatSize(bytes) {
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
  if (bytes < 1024 * 1024 * 1024) return (bytes / 1024 / 1024).toFixed(1) + ' MB';
  return (bytes / 1024 / 1024 / 1024).toFixed(1) + ' GB';
}
