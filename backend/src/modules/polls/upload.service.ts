import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import multer from 'multer';
import { Request, Response, NextFunction } from 'express';
import { env } from '../../config/env';
import { ValidationError } from '../../shared/errors/AppError';

const MAX_FILE_SIZE = 5 * 1024 * 1024; // 5MB
const ALLOWED_MIME_TYPES = new Set(['image/jpeg', 'image/png', 'image/webp']);

export interface UploadedPhotoResult {
  photoUrl: string;
  filename: string;
  size: number;
  mimeType: string;
}

export function validateImageMagicBytes(buffer: Buffer): { valid: boolean; ext: string; mimeType: string } {
  if (buffer.length < 12) {
    return { valid: false, ext: '', mimeType: '' };
  }

  // JPEG: FF D8 FF
  if (buffer[0] === 0xff && buffer[1] === 0xd8 && buffer[2] === 0xff) {
    return { valid: true, ext: 'jpg', mimeType: 'image/jpeg' };
  }

  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    buffer[0] === 0x89 &&
    buffer[1] === 0x50 &&
    buffer[2] === 0x4e &&
    buffer[3] === 0x47 &&
    buffer[4] === 0x0d &&
    buffer[5] === 0x0a &&
    buffer[6] === 0x1a &&
    buffer[7] === 0x0a
  ) {
    return { valid: true, ext: 'png', mimeType: 'image/png' };
  }

  // WebP: RIFF ... WEBP (offset 0: 'RIFF', offset 8: 'WEBP')
  if (
    buffer[0] === 0x52 &&
    buffer[1] === 0x49 &&
    buffer[2] === 0x46 &&
    buffer[3] === 0x46 &&
    buffer[8] === 0x57 &&
    buffer[9] === 0x45 &&
    buffer[10] === 0x42 &&
    buffer[11] === 0x50
  ) {
    return { valid: true, ext: 'webp', mimeType: 'image/webp' };
  }

  return { valid: false, ext: '', mimeType: '' };
}

// Memory storage so we can validate magic bytes before writing to persistent disk
const storage = multer.memoryStorage();

export const uploadPhotoMiddleware = multer({
  storage,
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 1,
  },
  fileFilter: (_req, file, cb) => {
    if (!ALLOWED_MIME_TYPES.has(file.mimetype.toLowerCase())) {
      return cb(
        new ValidationError('Invalid file type. Allowed formats: JPG, PNG, WebP')
      );
    }
    cb(null, true);
  },
}).single('photo');

export async function savePersonPhoto(
  fileBuffer: Buffer,
  clientMimeType?: string
): Promise<UploadedPhotoResult> {
  if (!fileBuffer || fileBuffer.length === 0) {
    throw new ValidationError('Photo file content is empty');
  }

  if (fileBuffer.length > MAX_FILE_SIZE) {
    throw new ValidationError('File size exceeds 5MB limit');
  }

  // Verify real file magic bytes (prevent disguised executables or HTML)
  const validation = validateImageMagicBytes(fileBuffer);
  if (!validation.valid) {
    throw new ValidationError('Invalid image content. File signature does not match JPG, PNG, or WebP');
  }

  const baseUploadDir = env.UPLOAD_DIR || path.resolve(process.cwd(), 'uploads');
  const targetSubdir = path.join('polls', 'people');
  const fullTargetDir = path.join(baseUploadDir, targetSubdir);

  // Ensure persistent directory exists
  await fs.promises.mkdir(fullTargetDir, { recursive: true });

  const uniqueId = crypto.randomUUID().replace(/-/g, '');
  const safeFilename = `poll_person_${Date.now()}_${uniqueId}.${validation.ext}`;
  const destinationPath = path.join(fullTargetDir, safeFilename);

  // Write file to disk
  await fs.promises.writeFile(destinationPath, fileBuffer);

  // Return public web-accessible path
  const photoUrl = `/uploads/${targetSubdir.replace(/\\/g, '/')}/${safeFilename}`;

  return {
    photoUrl,
    filename: safeFilename,
    size: fileBuffer.length,
    mimeType: validation.mimeType,
  };
}
