import { Request } from 'express';
import { UserRole } from '../constants';

export interface AuthenticatedUser {
  userId: string;
  email: string;
  role: UserRole;
  displayName: string;
  tokenVersion?: number;
  selectedPlaceId?: string | null;
  indigenousClassification?: string | null;
}

export interface AuthenticatedRequest extends Request {
  user?: AuthenticatedUser;
}

export interface AuthenticatedUploadRequest extends AuthenticatedRequest {
  file?: Express.Multer.File;
}

export interface PaginationQuery {
  page?: string;
  limit?: string;
}

export interface PaginationResult {
  page: number;
  limit: number;
  total: number;
  pages: number;
}

export interface ApiResponse<T> {
  data: T;
  pagination?: PaginationResult;
}

export interface LocalizedContent {
  original: string;
  language: string;
}
