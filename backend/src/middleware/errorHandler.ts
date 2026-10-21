import { Request, Response, NextFunction } from 'express';
import { AppError } from '../shared/errors/AppError';
import { env } from '../config/env';

export function errorHandler(err: Error, _req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        ...(err.isOperational && (err as any).details ? { details: (err as any).details } : {}),
      },
    });
    return;
  }

  // Handle payload too large error (HTTP 413)
  if ((err as any).status === 413 || (err as any).type === 'entity.too.large') {
    res.status(413).json({
      error: {
        code: 'PAYLOAD_TOO_LARGE',
        message: 'Request payload exceeds allowed limit',
      },
    });
    return;
  }

  // Handle MongoDB duplicate key error (E11000) safely without leaking database/index details
  if ((err as any).code === 11000) {
    res.status(409).json({
      error: {
        code: 'CONFLICT',
        message: 'A resource with the specified unique attributes already exists',
      },
    });
    return;
  }

  // Unhandled / unexpected error — never expose internals
  console.error('Unhandled error:', err);
  res.status(500).json({
    error: {
      code: 'INTERNAL_ERROR',
      message: env.NODE_ENV === 'development' ? err.message : 'An internal error occurred',
    },
  });
}
