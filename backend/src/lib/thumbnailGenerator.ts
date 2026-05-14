import { execSync, exec } from "child_process";
import fs from "fs";
import path from "path";
import { Storage } from "@google-cloud/storage";

const uploadsRoot = path.join(process.cwd(), "uploads");
const bucketName = process.env.GCS_BUCKET;
const storage = bucketName ? new Storage() : null;
const bucket = bucketName ? storage!.bucket(bucketName) : null;

type ThumbnailResult = {
  path: string;
  buffer?: Buffer;
} | null;

/**
 * Check if FFmpeg is available on the system
 */
export function isFfmpegAvailable(): boolean {
  try {
    execSync("ffmpeg -version", { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

/**
 * Generate a thumbnail for a video file
 * Returns the path where the thumbnail was saved
 */
export async function generateVideoThumbnail(
  inputPath: string,
  outputPath: string
): Promise<ThumbnailResult> {
  if (!isFfmpegAvailable()) {
    console.warn("FFmpeg not available for thumbnail generation");
    return null;
  }

  return new Promise((resolve) => {
    const ffmpegCommand = `ffmpeg -i "${inputPath}" -ss 00:00:01 -vframes 1 -vf "scale=320:-1" "${outputPath}" -y`;

    exec(ffmpegCommand, (error) => {
      if (error) {
        console.error("Thumbnail generation error:", error.message);
        resolve(null);
        return;
      }

      // Check if file was created
      if (fs.existsSync(outputPath)) {
        resolve({ path: outputPath });
      } else {
        resolve(null);
      }
    });
  });
}

/**
 * Generate thumbnail from a video file buffer and save it
 * Returns the relative path to the saved thumbnail or null if generation failed
 */
export async function generateAndSaveThumbnail(
  videoBuffer: Buffer,
  videoPath: string,
  thumbnailFolder: string
): Promise<string | null> {
  // Skip if FFmpeg is not available
  if (!isFfmpegAvailable()) {
    console.warn("FFmpeg not available, skipping thumbnail generation");
    return null;
  }

  try {
    // Ensure uploads root exists for local storage
    if (!bucket) {
      fs.mkdirSync(uploadsRoot, { recursive: true });
    }

    // Create temp video file
    const tempDir = path.join(uploadsRoot, ".temp");
    fs.mkdirSync(tempDir, { recursive: true });
    const tempVideoPath = path.join(tempDir, `video-${Date.now()}.tmp`);
    fs.writeFileSync(tempVideoPath, videoBuffer);

    // Generate thumbnail
    const fileName = path.basename(videoPath, path.extname(videoPath));
    const thumbnailFileName = `${fileName}-thumb.jpg`;
    const tempThumbnailPath = path.join(tempDir, thumbnailFileName);

    const result = await generateVideoThumbnail(tempVideoPath, tempThumbnailPath);

    if (!result || !fs.existsSync(tempThumbnailPath)) {
      // Clean up temp video
      try {
        fs.unlinkSync(tempVideoPath);
      } catch (e) {
        // ignore
      }
      return null;
    }

    // Read thumbnail and save it to the final location
    const thumbnailBuffer = fs.readFileSync(tempThumbnailPath);
    const finalThumbnailPath = `${thumbnailFolder}/${thumbnailFileName}`;

    let savedUrl = null;

    if (bucket) {
      // Save to GCS
      const target = bucket.file(finalThumbnailPath);
      await target.save(thumbnailBuffer, {
        resumable: false,
        metadata: {
          contentType: "image/jpeg",
          cacheControl: "public, max-age=31536000",
        },
      });
      savedUrl = `/uploads/${finalThumbnailPath}`;
    } else {
      // Save to local filesystem
      const fullPath = path.join(uploadsRoot, finalThumbnailPath);
      fs.mkdirSync(path.dirname(fullPath), { recursive: true });
      fs.writeFileSync(fullPath, thumbnailBuffer);
      savedUrl = `/uploads/${finalThumbnailPath}`;
    }

    // Clean up temp files
    try {
      fs.unlinkSync(tempVideoPath);
      fs.unlinkSync(tempThumbnailPath);
      // Remove temp dir if empty
      fs.rmdirSync(tempDir, { recursive: true });
    } catch (e) {
      // ignore cleanup errors
    }

    return savedUrl;
  } catch (error) {
    console.error("Error generating thumbnail:", error);
    return null;
  }
}
