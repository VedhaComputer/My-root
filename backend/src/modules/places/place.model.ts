import mongoose, { Schema, Document } from 'mongoose';
import { PLACE_LEVELS, PlaceLevel } from '../../shared/constants';

export interface IPlaceName {
  language: string;
  name: string;
}

export interface IGeoCoordinates {
  lat: number;
  lng: number;
}

export interface IPlace extends Document {
  level: PlaceLevel;
  canonicalName: string;
  canonicalNameLower: string;
  names: IPlaceName[];
  parentId: mongoose.Types.ObjectId | null;
  geoCoordinates?: IGeoCoordinates;
  createdBy?: mongoose.Types.ObjectId | null;
  updatedBy?: mongoose.Types.ObjectId | null;
  createdAt: Date;
  updatedAt: Date;
}

const PlaceNameSchema = new Schema<IPlaceName>(
  {
    language: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
    },
  },
  { _id: false }
);

const PlaceSchema = new Schema<IPlace>(
  {
    level: {
      type: String,
      enum: Object.values(PLACE_LEVELS),
      required: true,
      index: true,
    },
    canonicalName: {
      type: String,
      required: true,
      trim: true,
      minlength: 2,
      maxlength: 120,
    },
    canonicalNameLower: {
      type: String,
      required: true,
      trim: true,
      lowercase: true,
      select: false,
    },
    names: {
      type: [PlaceNameSchema],
      required: true,
      validate: [
        (val: IPlaceName[]) => Array.isArray(val) && val.length > 0,
        'At least one localized name is required',
      ],
    },
    parentId: {
      type: Schema.Types.ObjectId,
      ref: 'Place',
      default: null,
      index: true,
    },
    geoCoordinates: {
      lat: { type: Number, min: -90, max: 90 },
      lng: { type: Number, min: -180, max: 180 },
    },
    createdBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    updatedBy: {
      type: Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
  },
  {
    timestamps: true,
    toJSON: {
      transform(_doc, ret: Record<string, any>) {
        ret.id = ret._id ? ret._id.toString() : ret.id;
        if (ret.parentId && typeof ret.parentId === 'object' && ret.parentId._id) {
          ret.parentId = ret.parentId._id.toString();
        } else if (ret.parentId && typeof ret.parentId.toString === 'function') {
          ret.parentId = ret.parentId.toString();
        }
        delete ret._id;
        delete ret.__v;
        delete ret.canonicalNameLower;
        return ret;
      },
    },
  }
);

// Compound index for uniqueness: canonical name is unique under the same parent and level
PlaceSchema.index({ parentId: 1, level: 1, canonicalNameLower: 1 }, { unique: true });

export const PlaceModel =
  mongoose.models.Place || mongoose.model<IPlace>('Place', PlaceSchema);
