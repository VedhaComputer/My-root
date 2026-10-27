import mongoose, { ClientSession, FilterQuery } from 'mongoose';
import { IPoll, IPollVote, IPollReport, PollModel, PollVoteModel, PollReportModel, VoteChoice, PollStatus } from './poll.model';
import { AppError } from '../../shared/errors/AppError';

export class PollRepository {
  private static indexesInitialized = false;

  /**
   * Safely drops the legacy unique index { pollId: 1, userId: 1 } if present,
   * replacing it with { pollId: 1, userId: 1, questionId: 1 } to support multiple questions.
   * New index is created first to prevent unindexed windows.
   */
  public async ensureIndexesSafe(): Promise<void> {
    if (PollRepository.indexesInitialized || mongoose.connection.readyState !== 1) return;
    try {
      const collection = PollVoteModel.collection;
      const indexes = await collection.indexes();
      const hasOldIndex = indexes.some((idx) => idx.name === 'pollId_1_userId_1');
      const hasNewIndex = indexes.some(
        (idx) =>
          idx.name === 'pollId_1_userId_1_questionId_1' ||
          (idx.key && idx.key.pollId === 1 && idx.key.userId === 1 && idx.key.questionId === 1)
      );

      // Create new compound unique index first to maintain uniqueness guarantees
      if (!hasNewIndex) {
        await collection.createIndex({ pollId: 1, userId: 1, questionId: 1 }, { unique: true });
      }

      // Drop old index only after new index is safely active
      if (hasOldIndex) {
        await collection.dropIndex('pollId_1_userId_1');
      }

      PollRepository.indexesInitialized = true;
    } catch {
      // Ignore if collection not ready or in mock mode
    }
  }

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
    await this.ensureIndexesSafe().catch(() => {});
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
    questionId?: string,
    session?: ClientSession
  ): Promise<IPollVote | null> {
    const queryFilter: any = { pollId, userId };
    if (questionId && questionId !== 'default') {
      queryFilter.questionId = questionId;
    } else {
      queryFilter.$or = [
        { questionId: 'default' },
        { questionId: { $exists: false } },
        { questionId: null },
      ];
    }
    const query = PollVoteModel.findOne(queryFilter);
    if (session) query.session(session);
    return query;
  }

  async findUserVotesForPoll(
    pollId: string | mongoose.Types.ObjectId,
    userId: string | mongoose.Types.ObjectId,
    session?: ClientSession
  ): Promise<IPollVote[]> {
    const query = PollVoteModel.find({ pollId, userId });
    if (session) query.session(session);
    return query;
  }

  async createVote(
    data: {
      pollId: mongoose.Types.ObjectId;
      userId: mongoose.Types.ObjectId;
      questionId?: string;
      personId?: string | null;
      choice: VoteChoice;
      reasonKey: string;
      explanation?: string | null;
    },
    session?: ClientSession
  ): Promise<IPollVote> {
    await this.ensureIndexesSafe().catch(() => {});
    const payload = {
      ...data,
      questionId: data.questionId || 'default',
      personId: data.personId || null,
    };
    const docs = await PollVoteModel.create([payload], { session });
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

  async updatePersonVerificationStatus(
    pollId: string | mongoose.Types.ObjectId,
    personId: string | null,
    verificationStatus: 'UNVERIFIED' | 'SELF_CLAIMED' | 'DOCUMENTED' | 'VERIFIED',
    session?: ClientSession
  ): Promise<IPoll | null> {
    if (personId) {
      const isObjectId = mongoose.Types.ObjectId.isValid(personId);
      const query = PollModel.findOneAndUpdate(
        {
          _id: pollId,
          $or: [
            ...(isObjectId ? [{ 'people._id': new mongoose.Types.ObjectId(personId) }] : []),
            { 'people._id': personId },
            { 'people.id': personId },
          ],
        },
        { $set: { 'people.$.verificationStatus': verificationStatus } },
        { new: true }
      );
      if (session) query.session(session);
      const updated = await query;
      if (updated) return updated;
    }

    const queryFallback = PollModel.findOneAndUpdate(
      { _id: pollId },
      {
        $set: {
          verificationStatus,
          'people.0.verificationStatus': verificationStatus,
        },
      },
      { new: true }
    );
    if (session) queryFallback.session(session);
    return queryFallback;
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
    const poll = await this.findPollById(pollId, session);
    if (!poll) return null;

    const votes = await PollVoteModel.find({ pollId }, null, { session });
    let likeCount = 0;
    let dislikeCount = 0;
    const likeReasons: Record<string, number> = {};
    const dislikeReasons: Record<string, number> = {};

    // Map questionId -> question stats
    const questionStats: Record<string, { likeCount: number; dislikeCount: number; likeReasons: Record<string, number>; dislikeReasons: Record<string, number> }> = {};

    for (const v of votes) {
      const qId = v.questionId || 'default';
      if (!questionStats[qId]) {
        questionStats[qId] = { likeCount: 0, dislikeCount: 0, likeReasons: {}, dislikeReasons: {} };
      }

      if (v.choice === 'LIKE') {
        likeCount++;
        likeReasons[v.reasonKey] = (likeReasons[v.reasonKey] || 0) + 1;
        questionStats[qId].likeCount++;
        questionStats[qId].likeReasons[v.reasonKey] = (questionStats[qId].likeReasons[v.reasonKey] || 0) + 1;
      } else {
        dislikeCount++;
        dislikeReasons[v.reasonKey] = (dislikeReasons[v.reasonKey] || 0) + 1;
        questionStats[qId].dislikeCount++;
        questionStats[qId].dislikeReasons[v.reasonKey] = (questionStats[qId].dislikeReasons[v.reasonKey] || 0) + 1;
      }
    }

    const totalVotes = likeCount + dislikeCount;

    // Update questions array on poll
    if (poll.questions && poll.questions.length > 0) {
      poll.questions.forEach((q) => {
        const qId = q._id.toString();
        const stat = questionStats[qId] || questionStats['default'];
        if (stat) {
          q.likeCount = stat.likeCount;
          q.dislikeCount = stat.dislikeCount;
          q.totalVotes = stat.likeCount + stat.dislikeCount;
          q.likeReasons = stat.likeReasons;
          q.dislikeReasons = stat.dislikeReasons;
        }
      });
    }

    poll.totalVotes = totalVotes;
    poll.likeCount = likeCount;
    poll.dislikeCount = dislikeCount;
    poll.likeReasons = likeReasons;
    poll.dislikeReasons = dislikeReasons;

    await poll.save({ session });
    return poll;
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
