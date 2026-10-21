import mongoose, { Schema, Document } from 'mongoose';

export interface IPlaceAttributeHistory {
  value: string;
  sourceDescription: string;
  reportedPeriod?: string | null;
  reportedDate?: Date | null;
  uncertainty?: string | null;
  correctedBy: mongoose.Types.ObjectId;
  correctedAt: Date;
  correctionReason?: string | null;
}

export interface IPlaceAttribute extends Document {
  placeId: mongoose.Types.ObjectId;
  category: 'population' | 'leadership' | 'facility' | 'development' | 'issue' | 'identity';
  key: string;
  value: string;
  sourceDescription: string;
  reportedPeriod?: string | null;
  reportedDate?: Date | null;
  uncertainty?: string | null;
  submittedBy: mongoose.Types.ObjectId;
  status: 'pending_review' | 'verified' | 'rejected';
  reviewedBy?: mongoose.Types.ObjectId | null;
  reviewedAt?: Date | null;
  reviewNotes?: string | null;
  history?: IPlaceAttributeHistory[];
  isLatest: boolean;
  createdAt: Date;
  updatedAt: Date;
}

const PlaceAttributeHistorySchema = new Schema<IPlaceAttributeHistory>(
  {
    value: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000,
    },
    sourceDescription: {
      type: String,
      required: true,
      trim: true,
      maxlength: 500,
    },
    reportedPeriod: {
      type: String,
      trim: true,
      default: null,
    },
    reportedDate: {
      type: Date,
      default: null,
    },
    uncertainty: {
      type: String,
      trim: true,
      default: null,
    },
    correctedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    correctedAt: {
      type: Date,
      default: Date.now,
    },
    correctionReason: {
      type: String,
      trim: true,
      default: null,
      maxlength: 500,
    },
  },
  { _id: false }
);

const PlaceAttributeSchema = new Schema<IPlaceAttribute>(
  {
    placeId: {
      type: Schema.Types.ObjectId,
      ref: 'Place',
      required: true,
      index: true,
    },
    category: {
      type: String,
      required: true,
      enum: ['population', 'leadership', 'facility', 'development', 'issue', 'identity'],
      index: true,
    },
    key: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    value: {
      type: String,
      required: true,
      trim: true,
      maxlength: 1000,
    },
    sourceDescription: {
      type: String,
      required: true,
      trim: true,
      maxlength: 500,
    },
    reportedPeriod: {
      type: String,
      trim: true,
      default: null,
    },
    reportedDate: {
      type: Date,
      default: null,
    },
    uncertainty: {
      type: String,
      trim: true,
      default: null,
    },
    submittedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      required: true,
      index: true,
    },
    status: {
      type: String,
      enum: ['pending_review', 'verified', 'rejected'],
      default: 'pending_review',
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
      default: null,
      maxlength: 1000,
    },
    history: {
      type: [PlaceAttributeHistorySchema],
      default: [],
    },
    isLatest: {
      type: Boolean,
      default: true,
      index: true,
    },
  },
  {
    collection: 'place_attributes',
    timestamps: true,
  }
);

PlaceAttributeSchema.index({ placeId: 1, category: 1, createdAt: -1 });

export const PlaceAttributeModel = mongoose.model<IPlaceAttribute>('PlaceAttribute', PlaceAttributeSchema);
