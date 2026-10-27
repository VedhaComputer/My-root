import mongoose, { Schema, Document } from 'mongoose';

export type PollStatus = 'ACTIVE' | 'CLOSED' | 'REPORTED' | 'REMOVED';
export type VoteChoice = 'LIKE' | 'DISLIKE';
export type QuestionType = 'LIKE_DISLIKE' | 'CHOICE';

export interface IPollVote extends Document {
  pollId: mongoose.Types.ObjectId;
  userId: mongoose.Types.ObjectId;
  questionId: string;
  personId?: string | null;
  choice: VoteChoice;
  reasonKey: string;
  explanation?: string | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface IPollReport extends Document {
  pollId: mongoose.Types.ObjectId;
  reportedBy: mongoose.Types.ObjectId;
  reason: string;
  details?: string | null;
  status: 'PENDING' | 'RESOLVED' | 'DISMISSED';
  createdAt: Date;
}

export interface IPollPerson {
  _id: mongoose.Types.ObjectId;
  id?: string;
  name: string;
  role?: string | null;
  designation?: string | null;
  officeContext?: string | null;
  placeId?: string | null;
  placeName?: string | null;
  targetEntityId?: string | null;
  photoUrl?: string | null;
  workBackground?: string | null;
  publicServiceHistory?: string | null;
  education?: string | null;
  achievements?: string | null;
  casteCommunity?: string | null;
  religion?: string | null;
  bio?: string | null;
  sourceReference?: string | null;
  verificationStatus?: 'UNVERIFIED' | 'SELF_CLAIMED' | 'DOCUMENTED' | 'VERIFIED' | string;
}

export interface IPollQuestionOption {
  key: string;
  labelEn: string;
  labelHi: string;
}

export interface IPollQuestion {
  _id: mongoose.Types.ObjectId;
  id?: string;
  text: string;
  personId?: string | null;
  questionType: QuestionType;
  options?: IPollQuestionOption[];
  likeCount: number;
  dislikeCount: number;
  totalVotes: number;
  likeReasons: Record<string, number> | Map<string, number>;
  dislikeReasons: Record<string, number> | Map<string, number>;
}

export interface IPoll extends Document {
  purpose?: string | null;
  category?: string | null;
  people: IPollPerson[];
  questions: IPollQuestion[];
  // Legacy / top-level fields preserved for backward compatibility
  personName: string;
  personRole?: string | null;
  placeId?: string | null;
  placeName?: string | null;
  targetEntityId?: string | null;
  question: string;
  description?: string | null;
  photoUrl?: string | null;
  workBackground?: string | null;
  publicServiceHistory?: string | null;
  education?: string | null;
  achievements?: string | null;
  casteCommunity?: string | null;
  religion?: string | null;
  bio?: string | null;
  sourceReference?: string | null;
  verificationStatus?: 'UNVERIFIED' | 'SELF_CLAIMED' | 'DOCUMENTED' | 'VERIFIED' | string;
  status: PollStatus;
  startTime: Date;
  endTime?: Date | null;
  createdBy: mongoose.Types.ObjectId;
  creatorName?: string | null;
  likeCount: number;
  dislikeCount: number;
  totalVotes: number;
  likeReasons: Record<string, number> | Map<string, number>;
  dislikeReasons: Record<string, number> | Map<string, number>;
  reportsCount: number;
  createdAt: Date;
  updatedAt: Date;
}

const PollPersonSchema = new Schema<IPollPerson>(
  {
    name: { type: String, required: true, trim: true, minlength: 2, maxlength: 120 },
    role: { type: String, trim: true, maxlength: 100, default: null },
    designation: { type: String, trim: true, maxlength: 100, default: null },
    officeContext: { type: String, trim: true, maxlength: 150, default: null },
    placeId: { type: String, trim: true, default: null },
    placeName: { type: String, trim: true, maxlength: 150, default: null },
    targetEntityId: { type: String, trim: true, maxlength: 100, default: null },
    photoUrl: { type: String, trim: true, default: null },
    workBackground: { type: String, trim: true, maxlength: 1000, default: null },
    publicServiceHistory: { type: String, trim: true, maxlength: 2000, default: null },
    education: { type: String, trim: true, maxlength: 300, default: null },
    achievements: { type: String, trim: true, maxlength: 2000, default: null },
    casteCommunity: { type: String, trim: true, maxlength: 100, default: null },
    religion: { type: String, trim: true, maxlength: 100, default: null },
    bio: { type: String, trim: true, maxlength: 2000, default: null },
    sourceReference: { type: String, trim: true, maxlength: 500, default: null },
    verificationStatus: {
      type: String,
      enum: ['UNVERIFIED', 'SELF_CLAIMED', 'DOCUMENTED', 'VERIFIED'],
      default: 'UNVERIFIED',
    },
  },
  { _id: true }
);

const PollQuestionSchema = new Schema<IPollQuestion>(
  {
    text: { type: String, required: true, trim: true, minlength: 5, maxlength: 300 },
    personId: { type: String, trim: true, default: null },
    questionType: { type: String, enum: ['LIKE_DISLIKE', 'CHOICE'], default: 'LIKE_DISLIKE' },
    options: [
      {
        key: { type: String, required: true, trim: true },
        labelEn: { type: String, required: true, trim: true },
        labelHi: { type: String, required: true, trim: true },
      },
    ],
    likeCount: { type: Number, default: 0, min: 0 },
    dislikeCount: { type: Number, default: 0, min: 0 },
    totalVotes: { type: Number, default: 0, min: 0 },
    likeReasons: { type: Map, of: Number, default: () => new Map() },
    dislikeReasons: { type: Map, of: Number, default: () => new Map() },
  },
  { _id: true }
);

const PollVoteSchema = new Schema<IPollVote>(
  {
    pollId: { type: Schema.Types.ObjectId, ref: 'Poll', required: true, index: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    questionId: { type: String, required: true, trim: true, default: 'default', index: true },
    personId: { type: String, trim: true, default: null, index: true },
    choice: { type: String, enum: ['LIKE', 'DISLIKE'], required: true },
    reasonKey: { type: String, required: true, trim: true, maxlength: 60 },
    explanation: { type: String, trim: true, maxlength: 500, default: null },
  },
  { timestamps: true }
);

// One vote per user per poll question unique compound constraint
PollVoteSchema.index({ pollId: 1, userId: 1, questionId: 1 }, { unique: true });

const PollReportSchema = new Schema<IPollReport>(
  {
    pollId: { type: Schema.Types.ObjectId, ref: 'Poll', required: true, index: true },
    reportedBy: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    reason: { type: String, required: true, trim: true, maxlength: 100 },
    details: { type: String, trim: true, maxlength: 500, default: null },
    status: { type: String, enum: ['PENDING', 'RESOLVED', 'DISMISSED'], default: 'PENDING' },
  },
  { timestamps: true }
);

// Prevent duplicate reports from the same user on the same poll
PollReportSchema.index({ pollId: 1, reportedBy: 1 }, { unique: true });

const PollSchema = new Schema<IPoll>(
  {
    purpose: { type: String, trim: true, maxlength: 150, default: null },
    category: { type: String, trim: true, maxlength: 80, default: null },
    people: { type: [PollPersonSchema], default: [] },
    questions: { type: [PollQuestionSchema], default: [] },

    // Legacy fields
    personName: { type: String, required: true, trim: true, minlength: 2, maxlength: 120, index: true },
    personRole: { type: String, trim: true, maxlength: 100, default: null },
    placeId: { type: String, trim: true, index: true, default: null },
    placeName: { type: String, trim: true, maxlength: 150, default: null },
    targetEntityId: { type: String, trim: true, index: true, default: null },
    question: { type: String, required: true, trim: true, minlength: 5, maxlength: 300 },
    description: { type: String, trim: true, maxlength: 1000, default: null },
    photoUrl: { type: String, trim: true, default: null },
    status: {
      type: String,
      enum: ['ACTIVE', 'CLOSED', 'REPORTED', 'REMOVED'],
      default: 'ACTIVE',
      index: true,
    },
    startTime: { type: Date, default: Date.now },
    endTime: { type: Date, default: null },
    createdBy: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    creatorName: { type: String, trim: true, default: null },
    likeCount: { type: Number, default: 0, min: 0 },
    dislikeCount: { type: Number, default: 0, min: 0 },
    totalVotes: { type: Number, default: 0, min: 0 },
    likeReasons: { type: Map, of: Number, default: () => new Map() },
    dislikeReasons: { type: Map, of: Number, default: () => new Map() },
    reportsCount: { type: Number, default: 0, min: 0 },
  },
  { timestamps: true }
);

PollSchema.index({ personName: 'text', question: 'text', purpose: 'text' });
PollSchema.index({ placeId: 1, status: 1 });
PollSchema.index({ status: 1, createdAt: -1 });

export const PollModel = mongoose.model<IPoll>('Poll', PollSchema);
export const PollVoteModel = mongoose.model<IPollVote>('PollVote', PollVoteSchema);
export const PollReportModel = mongoose.model<IPollReport>('PollReport', PollReportSchema);
