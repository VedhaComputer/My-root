import mongoose, { Schema, Document } from 'mongoose';
import { REVIEW_DECISIONS, ReviewDecision } from '../../shared/constants';

export interface IReview extends Document {
  claimId: mongoose.Types.ObjectId;
  reviewerId: mongoose.Types.ObjectId;
  previousStatus: string;
  decisionStatus: ReviewDecision;
  reason: string;
  sourcesConsidered: mongoose.Types.ObjectId[];
  timestamp: Date;
  reviewerNote?: string;
  internalNote?: string;
  isAppealReview: boolean;
  appealsOriginalReviewId?: mongoose.Types.ObjectId | null;
}

const ReviewSchema = new Schema<IReview>(
  {
    claimId: {
      type: Schema.Types.ObjectId,
      ref: 'Claim',
      required: true,
      index: true,
    },
    reviewerId: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    previousStatus: {
      type: String,
      required: true,
    },
    decisionStatus: {
      type: String,
      required: true,
      enum: REVIEW_DECISIONS,
      index: true,
    },
    reason: {
      type: String,
      required: true,
      minlength: 20,
      maxlength: 5000,
      trim: true,
    },
    sourcesConsidered: [
      {
        type: Schema.Types.ObjectId,
        ref: 'Evidence',
        default: [],
      },
    ],
    timestamp: {
      type: Date,
      default: Date.now,
      index: true,
    },
    reviewerNote: {
      type: String,
      trim: true,
      default: '',
    },
    internalNote: {
      type: String,
      trim: true,
      default: '',
    },
    isAppealReview: {
      type: Boolean,
      default: false,
    },
    appealsOriginalReviewId: {
      type: Schema.Types.ObjectId,
      ref: 'Review',
      default: null,
    },
  },
  {
    collection: 'reviews',
    timestamps: false,
  }
);

ReviewSchema.index({ claimId: 1, reviewerId: 1, timestamp: -1 });

export const ReviewModel = mongoose.model<IReview>('Review', ReviewSchema);
