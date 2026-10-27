import fs from 'fs';
import path from 'path';
import {
  validateImageMagicBytes,
  savePersonPhoto,
} from '../../../../src/modules/polls/upload.service';
import { pollController } from '../../../../src/modules/polls/controller';
import { ValidationError, AuthenticationError } from '../../../../src/shared/errors/AppError';

describe('Poll Person Photo Upload Service (Unit Tests)', () => {
  const createdFiles: string[] = [];

  afterAll(async () => {
    for (const filePath of createdFiles) {
      try {
        await fs.promises.unlink(filePath);
      } catch {
        // ignore cleanup error
      }
    }
  });

  describe('validateImageMagicBytes', () => {
    it('accepts valid JPEG buffer', () => {
      const jpegBuffer = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]);
      const result = validateImageMagicBytes(jpegBuffer);
      expect(result.valid).toBe(true);
      expect(result.ext).toBe('jpg');
      expect(result.mimeType).toBe('image/jpeg');
    });

    it('accepts valid PNG buffer', () => {
      const pngBuffer = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x00, 0x00, 0x0d]);
      const result = validateImageMagicBytes(pngBuffer);
      expect(result.valid).toBe(true);
      expect(result.ext).toBe('png');
      expect(result.mimeType).toBe('image/png');
    });

    it('accepts valid WebP buffer', () => {
      const webpBuffer = Buffer.from([
        0x52, 0x49, 0x46, 0x46, // RIFF
        0x20, 0x00, 0x00, 0x00, // file size
        0x57, 0x45, 0x42, 0x50, // WEBP
      ]);
      const result = validateImageMagicBytes(webpBuffer);
      expect(result.valid).toBe(true);
      expect(result.ext).toBe('webp');
      expect(result.mimeType).toBe('image/webp');
    });

    it('rejects plain text or HTML disguised as image', () => {
      const htmlBuffer = Buffer.from('<html><body><script>alert(1)</script></body></html>');
      const result = validateImageMagicBytes(htmlBuffer);
      expect(result.valid).toBe(false);
      expect(result.ext).toBe('');
      expect(result.mimeType).toBe('');
    });

    it('rejects short buffer with fewer than 12 bytes', () => {
      const shortBuffer = Buffer.from([0xff, 0xd8, 0xff]);
      const result = validateImageMagicBytes(shortBuffer);
      expect(result.valid).toBe(false);
    });
  });

  describe('savePersonPhoto', () => {
    it('saves a valid PNG photo and returns web-accessible photoUrl', async () => {
      const validPng = Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        Buffer.alloc(100, 0x00),
      ]);

      const result = await savePersonPhoto(validPng, 'image/png');

      expect(result.photoUrl).toMatch(/^\/uploads\/polls\/people\/poll_person_\d+_[a-f0-9]+\.png$/);
      expect(result.filename).toMatch(/^poll_person_\d+_[a-f0-9]+\.png$/);
      expect(result.size).toBe(validPng.length);
      expect(result.mimeType).toBe('image/png');

      // Verify file exists on disk
      const diskPath = path.resolve(process.cwd(), result.photoUrl.replace(/^\//, ''));
      createdFiles.push(diskPath);
      expect(fs.existsSync(diskPath)).toBe(true);

      const written = await fs.promises.readFile(diskPath);
      expect(written.equals(validPng)).toBe(true);
    });

    it('saves a valid JPEG photo with safe randomized filename preventing traversal', async () => {
      const validJpeg = Buffer.concat([
        Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01]),
        Buffer.alloc(64, 0xab),
      ]);

      const result = await savePersonPhoto(validJpeg, 'image/jpeg');

      expect(result.photoUrl).toMatch(/^\/uploads\/polls\/people\/poll_person_\d+_[a-f0-9]+\.jpg$/);
      expect(result.filename.endsWith('.jpg')).toBe(true);
      expect(result.mimeType).toBe('image/jpeg');

      const diskPath = path.resolve(process.cwd(), result.photoUrl.replace(/^\//, ''));
      createdFiles.push(diskPath);
      expect(fs.existsSync(diskPath)).toBe(true);
    });

    it('rejects empty file buffer', async () => {
      await expect(savePersonPhoto(Buffer.alloc(0))).rejects.toThrow(ValidationError);
    });

    it('rejects files larger than 5MB', async () => {
      // 5MB + 1 byte
      const oversized = Buffer.alloc(5 * 1024 * 1024 + 1);
      await expect(savePersonPhoto(oversized)).rejects.toThrow('File size exceeds 5MB limit');
    });

    it('rejects invalid image content where signature does not match image format', async () => {
      const disguisedText = Buffer.from('This is a text file with .jpg extension');
      await expect(savePersonPhoto(disguisedText)).rejects.toThrow(
        'Invalid image content. File signature does not match JPG, PNG, or WebP'
      );
    });
  });

  describe('PollController.uploadPhoto', () => {
    it('throws AuthenticationError when req.user is missing', async () => {
      const req: any = { file: { buffer: Buffer.from([1, 2, 3]) } };
      const res: any = {};
      const next = jest.fn();
      await pollController.uploadPhoto(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(AuthenticationError));
    });

    it('throws ValidationError when file is missing', async () => {
      const req: any = { user: { userId: 'u1' } };
      const res: any = {};
      const next = jest.fn();
      await pollController.uploadPhoto(req, res, next);
      expect(next).toHaveBeenCalledWith(expect.any(ValidationError));
    });

    it('returns 200 with result when valid file is provided', async () => {
      const validPng = Buffer.concat([
        Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
        Buffer.alloc(20, 0x00),
      ]);
      const req: any = {
        user: { userId: 'u1' },
        file: { buffer: validPng, mimetype: 'image/png' },
      };
      const res: any = {
        status: jest.fn().mockReturnThis(),
        json: jest.fn(),
      };
      const next = jest.fn();
      await pollController.uploadPhoto(req, res, next);
      expect(next).not.toHaveBeenCalled();
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          data: expect.objectContaining({
            mimeType: 'image/png',
          }),
        })
      );
    });
  });
});
