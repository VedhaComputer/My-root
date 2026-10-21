import mongoose, { Schema, Document } from 'mongoose';
import {
  CLAIM_CATEGORIES,
  CLAIM_STATUSES,
  ClaimCategory,
  ClaimStatus,
} from '../../shared/constants';

export interface ILocalizedContent {
  original: string;
  language: string;
}

export interface IHistoryFeedback {
  _id: mongoose.Types.ObjectId;
  userId: mongoose.Types.ObjectId;
  previouslyKnown?: 'yes' | 'no' | 'partial' | null;
  agreement?: 'agree' | 'disagree' | 'need_evidence' | 'not_sure' | null;
  comment?: string | null;
  knowsAuthor?: 'personally' | 'by_name' | 'not_known' | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface ICorrectionRequest {
  _id: mongoose.Types.ObjectId;
  requestedBy: mongoose.Types.ObjectId;
  reason: string;
  proposedChanges?: {
    title?: string;
    body?: string;
    sourceAttribution?: string;
    timePeriod?: string;
  } | null;
  status: 'pending' | 'accepted' | 'rejected';
  reviewedBy?: mongoose.Types.ObjectId | null;
  reviewedAt?: Date | null;
  reviewNotes?: string | null;
  createdAt: Date;
}

export interface IClaim extends Document {
  title: ILocalizedContent;
  body: ILocalizedContent;
  category: ClaimCategory;
  status: ClaimStatus;
  locationId: mongoose.Types.ObjectId | string;
  locationPath: (mongoose.Types.ObjectId | string)[];
  submittedBy: mongoose.Types.ObjectId;
  submittedAt: Date;
  updatedAt: Date;
  tags: string[];
  evidenceIds: mongoose.Types.ObjectId[];
  isPublic: boolean;
  communityTopic?: string;
  sourceAttribution?: string;
  timePeriod?: string;
  consentObtained?: boolean;
  consentDetails?: string;
  consentState?: 'not_applicable' | 'pending_verification' | 'consent_verified' | 'consent_revoked';
  consentVerifiedBy?: mongoose.Types.ObjectId;
  consentVerifiedAt?: Date;
  consentNotes?: string;
  userAgreementStatus?: 'agreed' | 'correction' | 'different_account' | 'dont_know';
  correctionRequests?: ICorrectionRequest[];
  communityFeedbacks?: IHistoryFeedback[];
  __v?: number;
}

const LocalizedContentSchema = new Schema<ILocalizedContent>(
  {
    original: {
      type: String,
      required: true,
      trim: true,
    },
    language: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
    },
  },
  { _id: false }
);

const CorrectionRequestSchema = new Schema<ICorrectionRequest>(
  {
    requestedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    reason: {
      type: String,
      required: true,
      trim: true,
      maxlength: 2000,
    },
    proposedChanges: {
      type: Schema.Types.Mixed,
      default: null,
    },
    status: {
      type: String,
      enum: ['pending', 'accepted', 'rejected'],
      default: 'pending',
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
    createdAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: true }
);

const HistoryFeedbackSchema = new Schema<IHistoryFeedback>(
  {
    userId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    previouslyKnown: {
      type: String,
      enum: ['yes', 'no', 'partial', null],
      default: null,
    },
    agreement: {
      type: String,
      enum: ['agree', 'disagree', 'need_evidence', 'not_sure', null],
      default: null,
    },
    comment: {
      type: String,
      trim: true,
      maxlength: 2000,
      default: null,
    },
    knowsAuthor: {
      type: String,
      enum: ['personally', 'by_name', 'not_known', null],
      default: null,
    },
    createdAt: {
      type: Date,
      default: Date.now,
    },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
  },
  { _id: true }
);

const ClaimSchema = new Schema<IClaim>(
  {
    title: {
      type: LocalizedContentSchema,
      required: true,
    },
    body: {
      type: LocalizedContentSchema,
      required: true,
    },
    category: {
      type: String,
      required: true,
      enum: Object.values(CLAIM_CATEGORIES),
      index: true,
    },
    status: {
      type: String,
      required: true,
      enum: Object.values(CLAIM_STATUSES),
      default: CLAIM_STATUSES.DRAFT,
      index: true,
    },
    locationId: {
      type: Schema.Types.Mixed,
      required: true,
      index: true,
    },
    locationPath: [
      {
        type: Schema.Types.Mixed,
        index: true,
      },
    ],
    submittedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    submittedAt: {
      type: Date,
      default: Date.now,
      index: true,
    },
    updatedAt: {
      type: Date,
      default: Date.now,
    },
    tags: {
      type: [String],
      default: [],
    },
    evidenceIds: [
      {
        type: Schema.Types.ObjectId,
        ref: 'Evidence',
        default: [],
      },
    ],
    isPublic: {
      type: Boolean,
      default: true,
    },
    communityTopic: {
      type: String,
      trim: true,
      default: null,
      index: true,
    },
    sourceAttribution: {
      type: String,
      trim: true,
      default: null,
    },
    timePeriod: {
      type: String,
      trim: true,
      default: null,
    },
    consentObtained: {
      type: Boolean,
      default: false,
    },
    consentDetails: {
      type: String,
      trim: true,
      default: null,
    },
    consentState: {
      type: String,
      enum: ['not_applicable', 'pending_verification', 'consent_verified', 'consent_revoked'],
      default: 'not_applicable',
      index: true,
    },
    userAgreementStatus: {
      type: String,
      enum: ['agreed', 'correction', 'different_account', 'dont_know'],
      default: null,
    },
    consentVerifiedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    consentVerifiedAt: {
      type: Date,
      default: null,
    },
    consentNotes: {
      type: String,
      trim: true,
      maxlength: 1000,
      default: null,
    },
    correctionRequests: {
      type: [CorrectionRequestSchema],
      default: [],
    },
    communityFeedbacks: {
      type: [HistoryFeedbackSchema],
      default: [],
    },
  },
  {
    collection: 'claims',
    timestamps: { createdAt: false, updatedAt: 'updatedAt' },
  }
);

// Compound index as documented in architecture.md: compound (locationId, category, status)
ClaimSchema.index({ locationId: 1, category: 1, status: 1 });

// Text index on original content as documented in architecture.md
ClaimSchema.index({ 'title.original': 'text', 'body.original': 'text' });

export const ClaimModel = mongoose.model<IClaim>('Claim', ClaimSchema);
