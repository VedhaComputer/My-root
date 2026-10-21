import mongoose, { ClientSession } from 'mongoose';
import { ReviewModel, IReview } from './review.model';
import { SubmitReviewInput } from './validation';

export class ReviewRepository {
  async create(
    data: SubmitReviewInput & {
      reviewerId: string;
      previousStatus: string;
    },
    session?: ClientSession
  ): Promise<IReview> {
    const review = new ReviewModel({
      claimId: new mongoose.Types.ObjectId(data.claimId),
      reviewerId: new mongoose.Types.ObjectId(data.reviewerId),
      previousStatus: data.previousStatus,
      decisionStatus: data.decisionStatus,
      reason: data.reason.trim(),
      sourcesConsidered: (data.sourcesConsidered || []).map((id) => new mongoose.Types.ObjectId(id)),
      timestamp: new Date(),
      reviewerNote: data.reviewerNote ? data.reviewerNote.trim() : '',
      isAppealReview: false,
    });

    return await review.save({ session });
  }

  async findByClaimId(claimId: string, session?: ClientSession): Promise<IReview[]> {
    if (!mongoose.Types.ObjectId.isValid(claimId)) return [];
    const q = ReviewModel.find({ claimId: new mongoose.Types.ObjectId(claimId) }).sort({ timestamp: -1 });
    if (session) q.session(session);
    return await q.exec();
  }

  async findLatestByClaimId(claimId: string, session?: ClientSession): Promise<IReview | null> {
    if (!mongoose.Types.ObjectId.isValid(claimId)) return null;
    const q = ReviewModel.findOne({ claimId: new mongoose.Types.ObjectId(claimId) }).sort({ timestamp: -1 });
    if (session) q.session(session);
    return await q.exec();
  }
}

export const reviewRepository = new ReviewRepository();
