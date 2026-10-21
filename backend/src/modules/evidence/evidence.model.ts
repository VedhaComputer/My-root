import mongoose, { Schema, Document } from 'mongoose';
import { EVIDENCE_SOURCE_TYPES, EvidenceSourceType } from '../../shared/constants';

export interface IEvidence extends Document {
  claimId: mongoose.Types.ObjectId;
  sourceType: EvidenceSourceType;
  title: string;
  description: string;
  url?: string | null;
  documentRef?: string | null;
  dateOfEvidence?: Date | null;
  retrievedAt?: Date | null;
  languageOfEvidence: string;
  uploadedBy: mongoose.Types.ObjectId;
  uploadedAt: Date;
  status: 'submitted' | 'verified' | 'rejected' | 'disputed';
  reviewedBy?: mongoose.Types.ObjectId | null;
  reviewedAt?: Date | null;
  reviewNotes?: string | null;
  counterEvidenceIds: mongoose.Types.ObjectId[];
}

const EvidenceSchema = new Schema<IEvidence>(
  {
    claimId: {
      type: Schema.Types.ObjectId,
      ref: 'Claim',
      required: true,
      index: true,
    },
    sourceType: {
      type: String,
      required: true,
      enum: EVIDENCE_SOURCE_TYPES,
      index: true,
    },
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 300,
    },
    description: {
      type: String,
      required: true,
      trim: true,
      maxlength: 5000,
    },
    url: {
      type: String,
      trim: true,
      default: null,
    },
    documentRef: {
      type: String,
      trim: true,
      default: null,
    },
    dateOfEvidence: {
      type: Date,
      default: null,
    },
    retrievedAt: {
      type: Date,
      default: null,
    },
    languageOfEvidence: {
      type: String,
      default: 'en',
      trim: true,
      lowercase: true,
    },
    uploadedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    uploadedAt: {
      type: Date,
      default: Date.now,
    },
    status: {
      type: String,
      enum: ['submitted', 'verified', 'rejected', 'disputed'],
      default: 'submitted',
      index: true,
    },
    reviewedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    reviewedAt: {
      type: Date,
      default: null,
    },
    reviewNotes: {
      type: String,
      trim: true,
      maxlength: 2000,
      default: null,
    },
    counterEvidenceIds: [
      {
        type: Schema.Types.ObjectId,
        ref: 'Evidence',
        default: [],
      },
    ],
  },
  {
    collection: 'evidence',
    timestamps: false,
  }
);

EvidenceSchema.index({ claimId: 1, uploadedBy: 1, sourceType: 1 });

export const EvidenceModel = mongoose.model<IEvidence>('Evidence', EvidenceSchema);
