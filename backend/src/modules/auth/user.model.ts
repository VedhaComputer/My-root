import mongoose, { Schema, Document } from 'mongoose';
import crypto from 'crypto';
import { USER_ROLES, UserRole } from '../../shared/constants';

export interface IUser extends Document {
  displayName: string;
  email: string;
  emailHash: string;
  passwordHash: string;
  role: UserRole;
  isIdentityVerified: boolean;
  verifiedLocationId: mongoose.Types.ObjectId | null;
  selectedPlaceId?: string | mongoose.Types.ObjectId | null;
  matrbhoomiHistoryInterest?: {
    placeId: string;
    knowsHistory?: boolean | null;
    wantsToLearn?: boolean | null;
    answeredAt: Date;
  } | null;
  matrbhoomiHistoryInterests?: Array<{
    placeId: string;
    knowsHistory?: boolean | null;
    wantsToLearn?: boolean | null;
    answeredAt: Date;
  }>;
  joinedAt: Date;
  isActive: boolean;
  tokenVersion: number;
  isEmailVerified: boolean;
  emailVerificationTokenHash?: string | null;
  emailVerificationExpiresAt?: Date | null;
  passwordResetTokenHash?: string | null;
  passwordResetExpiresAt?: Date | null;
}

export function hashEmail(email: string): string {
  return crypto.createHash('sha256').update(email.trim().toLowerCase()).digest('hex');
}

export function hashAuthToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

const UserSchema = new Schema<IUser>(
  {
    displayName: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 100,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
      select: false,
    },
    emailHash: {
      type: String,
      required: true,
      unique: true,
      index: true,
      select: false,
    },
    passwordHash: {
      type: String,
      required: true,
      select: false,
    },
    role: {
      type: String,
      enum: Object.values(USER_ROLES),
      default: USER_ROLES.CONTRIBUTOR,
      index: true,
    },
    isIdentityVerified: {
      type: Boolean,
      default: false,
    },
    verifiedLocationId: {
      type: Schema.Types.ObjectId,
      ref: 'Place',
      default: null,
    },
    selectedPlaceId: {
      type: Schema.Types.Mixed,
      default: null,
    },
    matrbhoomiHistoryInterest: {
      type: {
        placeId: { type: String, required: true },
        knowsHistory: { type: Boolean, default: null },
        wantsToLearn: { type: Boolean, default: null },
        answeredAt: { type: Date, default: Date.now },
      },
      default: null,
      _id: false,
    },
    matrbhoomiHistoryInterests: {
      type: [
        {
          placeId: { type: String, required: true },
          knowsHistory: { type: Boolean, default: null },
          wantsToLearn: { type: Boolean, default: null },
          answeredAt: { type: Date, default: Date.now },
        },
      ],
      default: [],
      _id: false,
    },
    joinedAt: {
      type: Date,
      default: Date.now,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
    tokenVersion: {
      type: Number,
      default: 1,
    },
    isEmailVerified: {
      type: Boolean,
      default: false,
    },
    emailVerificationTokenHash: {
      type: String,
      default: null,
      select: false,
    },
    emailVerificationExpiresAt: {
      type: Date,
      default: null,
      select: false,
    },
    passwordResetTokenHash: {
      type: String,
      default: null,
      select: false,
    },
    passwordResetExpiresAt: {
      type: Date,
      default: null,
      select: false,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(_doc, ret: Record<string, any>) {
        ret.id = ret._id ? ret._id.toString() : ret.id;
        delete ret._id;
        delete ret.__v;
        delete ret.passwordHash;
        delete ret.email;
        delete ret.emailHash;
        return ret;
      },
    },
  }
);

export const UserModel = mongoose.models.User || mongoose.model<IUser>('User', UserSchema);
