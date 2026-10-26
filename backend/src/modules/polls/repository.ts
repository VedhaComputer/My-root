import mongoose, { ClientSession, FilterQuery } from 'mongoose';
import { IPoll, IPollVote, IPollReport, PollModel, PollVoteModel, PollReportModel, VoteChoice, PollStatus } from './poll.model';
import { AppError } from '../../shared/errors/AppError';

export class PollRepository {
  /**
   * Evaluates deployment topology upfront to determine whether multi-document ACID
   * transactions are supported (Replica Set or Sharded Cluster).
   */
  public supportsTransactions(): boolean {
    try {
      const client = mongoose.connection.getClient() as any;
      const desc = client?.topology?.description;
      if (!desc) {
        return false;
      }
      const type = desc.type;
      if (type === 'ReplicaSetWithPrimary' || type === 'Sharded') {
        return true;
      }
      if (type === 'Single' && desc.servers) {
        for (const server of desc.servers.values()) {
          if (server?.type === 'RSPrimary') {
            return true;
          }
        }
      }
      return false;
    } catch {
      return false;
    }
  }

  /**
   * Executes a unit of work inside a managed MongoDB transaction when supported,
   * with session propagation. Falls back to direct execution in non-production standalone.
   */
  async withTransaction<T>(work: (session?: ClientSession) => Promise<T>): Promise<T> {
    const isProduction = process.env.NODE_ENV === 'production';
    const hasTransactions = this.supportsTransactions();

    if (!hasTransactions) {
      if (isProduction) {
        throw new AppError(
          'Production requires a replica-set or sharded MongoDB deployment for multi-document ACID transactions.',
          500,
          'TRANSACTIONS_NOT_SUPPORTED',
          true
        );
      }
      // Non-production standalone fallback: execute unit of work directly
      return await work(undefined);
    }

    const session = await mongoose.startSession();
    try {
      let result: T;
      await session.withTransaction(
        async () => {
          result = await work(session);
        },
        {
          readPreference: 'primary',
          readConcern: { level: 'local' },
          writeConcern: { w: 'majority' },
        }
      );
      return result!;
    } finally {
      await session.endSession();
    }
  }

  async createPoll(data: Partial<IPoll>, session?: ClientSession): Promise<IPoll> {
    const docs = await PollModel.create([data], { session });
    return docs[0];
  }

  async findPollById(
    id: string | mongoose.Types.ObjectId,
    session?: ClientSession
  ): Promise<IPoll | null> {
    if (!mongoose.Types.ObjectId.isValid(id.toString())) {
      return null;
    }
    const query = PollModel.findById(id);
    if (session) query.session(session);
    return query;
  }

  async findPolls(
    filter: FilterQuery<IPoll>,
    page = 1,
    limit = 20
  ): Promise<{ polls: IPoll[]; total: number; pages: number }> {
    const skip = (page - 1) * limit;
    const [polls, total] = await Promise.all([
      PollModel.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
      PollModel.countDocuments(filter),
    ]);
    const pages = Math.ceil(total / limit) || 1;
    return { polls, total, pages };
  }

  async findUserVote(
    pollId: string | mongoose.Types.ObjectId,
    userId: string | mongoose.Types.ObjectId,
    session?: ClientSession
  ): Promise<IPollVote | null> {
    const query = PollVoteModel.findOne({ pollId, userId });
    if (session) query.session(session);
    return query;
  }

  async createVote(
    data: {
      pollId: mongoose.Types.ObjectId;
      userId: mongoose.Types.ObjectId;
      choice: VoteChoice;
      reasonKey: string;
      explanation?: string | null;
    },
    session?: ClientSession
  ): Promise<IPollVote> {
    const docs = await PollVoteModel.create([data], { session });
    return docs[0];
  }

  /**
   * Optimistically updates an existing vote record only if its current choice and reason match
   * the expected state. Returns null if another concurrent request already transitioned it.
   */
  async atomicUpdateVote(
    voteId: mongoose.Types.ObjectId,
    expectedChoice: VoteChoice,
    expectedReasonKey: string,
    update: {
      choice: VoteChoice;
      reasonKey: string;
      explanation?: string | null;
    },
    session?: ClientSession
  ): Promise<IPollVote | null> {
    const query = PollVoteModel.findOneAndUpdate(
      {
        _id: voteId,
        choice: expectedChoice,
        reasonKey: expectedReasonKey,
      },
      {
        $set: {
          choice: update.choice,
          reasonKey: update.reasonKey,
          explanation: update.explanation,
        },
      },
      { new: true }
    );
    if (session) query.session(session);
    return query;
  }

  async updateVoteExplanation(
    voteId: mongoose.Types.ObjectId,
    explanation: string | null,
    session?: ClientSession
  ): Promise<IPollVote | null> {
    const query = PollVoteModel.findByIdAndUpdate(
      voteId,
      { $set: { explanation } },
      { new: true }
    );
    if (session) query.session(session);
    return query;
  }

  async applyVoteIncrements(
    pollId: mongoose.Types.ObjectId | string,
    inc: Record<string, number>,
    session?: ClientSession
  ): Promise<IPoll | null> {
    const query = PollModel.findByIdAndUpdate(pollId, { $inc: inc }, { new: true });
    if (session) query.session(session);
    return query;
  }

  async closePoll(
    pollId: string | mongoose.Types.ObjectId,
    session?: ClientSession
  ): Promise<IPoll | null> {
    const query = PollModel.findByIdAndUpdate(
      pollId,
      { $set: { status: 'CLOSED', endTime: new Date() } },
      { new: true }
    );
    if (session) query.session(session);
    return query;
  }

  async updatePollStatus(
    pollId: string | mongoose.Types.ObjectId,
    status: PollStatus,
    session?: ClientSession
  ): Promise<IPoll | null> {
    const query = PollModel.findByIdAndUpdate(pollId, { $set: { status } }, { new: true });
    if (session) query.session(session);
    return query;
  }

  async findReport(
    pollId: mongoose.Types.ObjectId,
    reportedBy: mongoose.Types.ObjectId,
    session?: ClientSession
  ): Promise<IPollReport | null> {
    const query = PollReportModel.findOne({ pollId, reportedBy });
    if (session) query.session(session);
    return query;
  }

  async createReport(
    data: {
      pollId: mongoose.Types.ObjectId;
      reportedBy: mongoose.Types.ObjectId;
      reason: string;
      details?: string | null;
    },
    session?: ClientSession
  ): Promise<{ report: IPollReport; newReportsCount: number }> {
    const docs = await PollReportModel.create([data], { session });
    const report = docs[0];
    const updatedPoll = await this.applyVoteIncrements(data.pollId, { reportsCount: 1 }, session);
    return { report, newReportsCount: updatedPoll?.reportsCount || 1 };
  }

  async reconcilePollCounters(
    pollId: string | mongoose.Types.ObjectId,
    session?: ClientSession
  ): Promise<IPoll | null> {
    const votes = await PollVoteModel.find({ pollId }, null, { session });
    let likeCount = 0;
    let dislikeCount = 0;
    const likeReasons: Record<string, number> = {};
    const dislikeReasons: Record<string, number> = {};

    for (const v of votes) {
      if (v.choice === 'LIKE') {
        likeCount++;
        likeReasons[v.reasonKey] = (likeReasons[v.reasonKey] || 0) + 1;
      } else {
        dislikeCount++;
        dislikeReasons[v.reasonKey] = (dislikeReasons[v.reasonKey] || 0) + 1;
      }
    }

    const totalVotes = likeCount + dislikeCount;

    const query = PollModel.findByIdAndUpdate(
      pollId,
      {
        $set: {
          totalVotes,
          likeCount,
          dislikeCount,
          likeReasons,
          dislikeReasons,
        },
      },
      { new: true }
    );
    if (session) query.session(session);
    return query;
  }

  async resetPollReports(
    pollId: string | mongoose.Types.ObjectId,
    restoreStatus = 'ACTIVE' as PollStatus,
    session?: ClientSession
  ): Promise<IPoll | null> {
    await PollReportModel.updateMany(
      { pollId },
      { $set: { status: 'DISMISSED' } },
      { session }
    );
    const query = PollModel.findByIdAndUpdate(
      pollId,
      { $set: { reportsCount: 0, status: restoreStatus } },
      { new: true }
    );
    if (session) query.session(session);
    return query;
  }
}

export const pollRepository = new PollRepository();
