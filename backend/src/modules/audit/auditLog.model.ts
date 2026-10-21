import mongoose, { Schema, Document } from 'mongoose';

export type AuditEntityType = 'claim' | 'review' | 'user' | 'place' | 'evidence';

export interface IAuditLog extends Document {
  entityType: AuditEntityType;
  entityId: mongoose.Types.ObjectId;
  actorId: mongoose.Types.ObjectId;
  action: string;
  before: Record<string, any> | null;
  after: Record<string, any> | null;
  timestamp: Date;
  ipAddress?: string | null;
  metadata?: Record<string, any> | null;
}

const AuditLogSchema = new Schema<IAuditLog>(
  {
    entityType: {
      type: String,
      required: true,
      enum: ['claim', 'review', 'user', 'place', 'evidence'],
      index: true,
    },
    entityId: {
      type: Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    actorId: {
      type: Schema.Types.ObjectId,
      required: true,
      index: true,
    },
    action: {
      type: String,
      required: true,
      trim: true,
    },
    before: {
      type: Schema.Types.Mixed,
      default: null,
    },
    after: {
      type: Schema.Types.Mixed,
      default: null,
    },
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
    ipAddress: {
      type: String,
      default: null,
    },
    metadata: {
      type: Schema.Types.Mixed,
      default: null,
    },
  },
  {
    collection: 'auditLogs',
    timestamps: false,
    versionKey: false,
  }
);

export const AuditLogModel = mongoose.model<IAuditLog>('AuditLog', AuditLogSchema);
