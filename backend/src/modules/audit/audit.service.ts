import mongoose, { ClientSession } from 'mongoose';
import { AuditLogModel, IAuditLog, AuditEntityType } from './auditLog.model';

export interface WriteAuditLogInput {
  entityType: AuditEntityType;
  entityId: string | mongoose.Types.ObjectId;
  actorId: string | mongoose.Types.ObjectId;
  action: string;
  before?: Record<string, any> | null;
  after?: Record<string, any> | null;
  ipAddress?: string | null;
  metadata?: Record<string, any> | null;
}

export class AuditService {
  /**
   * Writes an immutable audit log record within the provided MongoDB ClientSession.
   * If the transaction session aborts, this log entry will automatically roll back.
   */
  async writeAuditLog(
    input: WriteAuditLogInput,
    session?: ClientSession
  ): Promise<IAuditLog> {
    const entityId =
      typeof input.entityId === 'string'
        ? new mongoose.Types.ObjectId(input.entityId)
        : input.entityId;

    const actorId =
      typeof input.actorId === 'string'
        ? new mongoose.Types.ObjectId(input.actorId)
        : input.actorId;

    const auditLog = new AuditLogModel({
      entityType: input.entityType,
      entityId,
      actorId,
      action: input.action,
      before: input.before ?? null,
      after: input.after ?? null,
      timestamp: new Date(),
      ipAddress: input.ipAddress ?? null,
      metadata: input.metadata ?? null,
    });

    return await auditLog.save({ session });
  }
}

export const auditService = new AuditService();
