import mongoose, { ClientSession } from 'mongoose';
import { pollRepository, PollRepository } from './repository';
import { IPoll, IPollVote, VoteChoice, PollStatus } from './poll.model';
import { NotFoundError, ValidationError, AuthorizationError } from '../../shared/errors/AppError';
import { USER_ROLES, UserRole } from '../../shared/constants';

export interface ReasonBreakdownItem {
  key: string;
  count: number;
  percentage: number;
}

export interface PollResponseDto {
  id: string;
  personName: string;
  personRole?: string | null;
  placeId?: string | null;
  placeName?: string | null;
  targetEntityId?: string | null;
  question: string;
  description?: string | null;
  photoUrl?: string | null;
  status: string;
  startTime: string;
  endTime?: string | null;
  createdBy: string;
  creatorName?: string | null;
  likeCount: number;
  dislikeCount: number;
  totalVotes: number;
  likePercentage: number;
  dislikePercentage: number;
  likeReasons: ReasonBreakdownItem[];
  dislikeReasons: ReasonBreakdownItem[];
  reportsCount: number;
  userVote?: {
    choice: VoteChoice;
    reasonKey: string;
    explanation?: string | null;
    updatedAt: string;
  } | null;
  createdAt: string;
  updatedAt: string;
}

export class PollService {
  constructor(private readonly repo: PollRepository = pollRepository) {}

  public formatPollDto(poll: IPoll, userVote?: IPollVote | null): PollResponseDto {
    const totalVotes = poll.totalVotes || (poll.likeCount + poll.dislikeCount) || 0;
    const likeCount = poll.likeCount || 0;
    const dislikeCount = poll.dislikeCount || 0;

    const likePercentage = totalVotes > 0 ? Number(((likeCount / totalVotes) * 100).toFixed(1)) : 0;
    const dislikePercentage = totalVotes > 0 ? Number(((dislikeCount / totalVotes) * 100).toFixed(1)) : 0;

    // Convert Map/Object to sorted reason breakdown items
    const rawLikeReasons: Record<string, number> =
      poll.likeReasons instanceof Map
        ? Object.fromEntries(poll.likeReasons)
        : (poll.likeReasons as Record<string, number>) || {};

    const rawDislikeReasons: Record<string, number> =
      poll.dislikeReasons instanceof Map
        ? Object.fromEntries(poll.dislikeReasons)
        : (poll.dislikeReasons as Record<string, number>) || {};

    const likeReasons: ReasonBreakdownItem[] = Object.entries(rawLikeReasons)
      .map(([key, count]) => ({
        key,
        count,
        percentage: likeCount > 0 ? Number(((count / likeCount) * 100).toFixed(1)) : 0,
      }))
      .sort((a, b) => b.count - a.count);

    const dislikeReasons: ReasonBreakdownItem[] = Object.entries(rawDislikeReasons)
      .map(([key, count]) => ({
        key,
        count,
        percentage: dislikeCount > 0 ? Number(((count / dislikeCount) * 100).toFixed(1)) : 0,
      }))
      .sort((a, b) => b.count - a.count);

    return {
      id: poll._id.toString(),
      personName: poll.personName,
      personRole: poll.personRole,
      placeId: poll.placeId,
      placeName: poll.placeName,
      targetEntityId: poll.targetEntityId,
      question: poll.question,
      description: poll.description,
      photoUrl: poll.photoUrl,
      status: poll.status,
      startTime: poll.startTime.toISOString(),
      endTime: poll.endTime ? poll.endTime.toISOString() : null,
      createdBy: poll.createdBy.toString(),
      creatorName: poll.creatorName,
      likeCount,
      dislikeCount,
      totalVotes,
      likePercentage,
      dislikePercentage,
      likeReasons,
      dislikeReasons,
      reportsCount: poll.reportsCount || 0,
      userVote: userVote
        ? {
            choice: userVote.choice,
            reasonKey: userVote.reasonKey,
            explanation: userVote.explanation,
            updatedAt: userVote.updatedAt.toISOString(),
          }
        : null,
      createdAt: poll.createdAt.toISOString(),
      updatedAt: poll.updatedAt.toISOString(),
    };
  }

  async createPoll(
    userId: string,
    userName: string,
    input: {
      personName: string;
      personRole?: string | null;
      placeId?: string | null;
      placeName?: string | null;
      targetEntityId?: string | null;
      question: string;
      description?: string | null;
      photoUrl?: string | null;
      durationDays?: number | null;
    }
  ): Promise<PollResponseDto> {
    const startTime = new Date();
    let endTime: Date | null = null;
    if (input.durationDays && input.durationDays > 0) {
      endTime = new Date(startTime.getTime() + input.durationDays * 24 * 60 * 60 * 1000);
    }

    const poll = await this.repo.createPoll({
      personName: input.personName.trim(),
      personRole: input.personRole?.trim() || null,
      placeId: input.placeId?.trim() || null,
      placeName: input.placeName?.trim() || null,
      targetEntityId: input.targetEntityId?.trim() || null,
      question: input.question.trim(),
      description: input.description?.trim() || null,
      photoUrl: input.photoUrl?.trim() || null,
      status: 'ACTIVE',
      startTime,
      endTime,
      createdBy: new mongoose.Types.ObjectId(userId),
      creatorName: userName,
      likeCount: 0,
      dislikeCount: 0,
      totalVotes: 0,
      likeReasons: {},
      dislikeReasons: {},
      reportsCount: 0,
    });

    return this.formatPollDto(poll);
  }

  async getPollById(pollId: string, currentUserId?: string): Promise<PollResponseDto> {
    const poll = await this.repo.findPollById(pollId);
    if (!poll || poll.status === 'REMOVED') {
      throw new NotFoundError('Poll not found');
    }

    // Auto-expiry check
    if (poll.status === 'ACTIVE' && poll.endTime && poll.endTime < new Date()) {
      poll.status = 'CLOSED';
      await poll.save();
    }

    let userVote: IPollVote | null = null;
    if (currentUserId && mongoose.Types.ObjectId.isValid(currentUserId)) {
      userVote = await this.repo.findUserVote(poll._id, currentUserId);
    }

    return this.formatPollDto(poll, userVote);
  }

  async listPolls(query: {
    personName?: string;
    placeId?: string;
    targetEntityId?: string;
    status?: string;
    search?: string;
    page?: number;
    limit?: number;
  }): Promise<{ data: PollResponseDto[]; pagination: { page: number; limit: number; total: number; pages: number } }> {
    const filter: Record<string, any> = {
      status: { $ne: 'REMOVED' },
    };

    if (query.status) {
      filter.status = query.status;
    }
    if (query.placeId) {
      filter.placeId = query.placeId;
    }
    if (query.targetEntityId) {
      filter.targetEntityId = query.targetEntityId;
    }
    if (query.personName) {
      filter.personName = { $regex: query.personName.trim(), $options: 'i' };
    }
    if (query.search) {
      const term = query.search.trim();
      filter.$or = [
        { personName: { $regex: term, $options: 'i' } },
        { question: { $regex: term, $options: 'i' } },
        { personRole: { $regex: term, $options: 'i' } },
        { placeName: { $regex: term, $options: 'i' } },
      ];
    }

    const page = query.page || 1;
    const limit = query.limit || 20;

    const { polls, total, pages } = await this.repo.findPolls(filter, page, limit);

    const now = new Date();
    const dtos = await Promise.all(
      polls.map(async (poll) => {
        if (poll.status === 'ACTIVE' && poll.endTime && poll.endTime < now) {
          poll.status = 'CLOSED';
          await poll.save();
        }
        return this.formatPollDto(poll);
      })
    );

    return {
      data: dtos,
      pagination: { page, limit, total, pages },
    };
  }

  async castVote(
    pollId: string,
    userId: string,
    input: {
      choice: VoteChoice;
      reasonKey: string;
      explanation?: string | null;
    }
  ): Promise<PollResponseDto> {
    const pollObjectId = mongoose.Types.ObjectId.isValid(pollId)
      ? new mongoose.Types.ObjectId(pollId)
      : (pollId as any);
    const userObjectId = mongoose.Types.ObjectId.isValid(userId)
      ? new mongoose.Types.ObjectId(userId)
      : (userId as any);

    return this.repo.withTransaction(async (session) => {
      const poll = await this.repo.findPollById(pollObjectId, session);
      if (!poll || poll.status === 'REMOVED') {
        throw new NotFoundError('Poll not found');
      }

      // Check expiry
      if (poll.status === 'ACTIVE' && poll.endTime && poll.endTime < new Date()) {
        poll.status = 'CLOSED';
        await poll.save({ session });
      }

      if (poll.status !== 'ACTIVE') {
        throw new ValidationError('This poll is closed and no longer accepting votes');
      }

      const existingVote = await this.repo.findUserVote(pollObjectId, userObjectId, session);

      let finalVote: IPollVote;

      if (!existingVote) {
        // User has not voted yet: Attempt to create new vote
        try {
          finalVote = await this.repo.createVote(
            {
              pollId: pollObjectId,
              userId: userObjectId,
              choice: input.choice,
              reasonKey: input.reasonKey,
              explanation: input.explanation?.trim() || null,
            },
            session
          );

          const incField = input.choice === 'LIKE' ? 'likeCount' : 'dislikeCount';
          const reasonField =
            input.choice === 'LIKE'
              ? `likeReasons.${input.reasonKey}`
              : `dislikeReasons.${input.reasonKey}`;

          await this.repo.applyVoteIncrements(
            pollObjectId,
            {
              totalVotes: 1,
              [incField]: 1,
              [reasonField]: 1,
            },
            session
          );
        } catch (err: any) {
          // Handle race condition on duplicate initial submission (code 11000)
          if (err?.code === 11000) {
            const createdVote = await this.repo.findUserVote(pollObjectId, userObjectId, session);
            if (!createdVote) {
              throw err;
            }
            if (createdVote.choice === input.choice && createdVote.reasonKey === input.reasonKey) {
              finalVote = createdVote;
            } else {
              finalVote = await this.applyVoteSwitch(poll, createdVote, input, session);
            }
          } else {
            throw err;
          }
        }
      } else {
        // Existing vote found: switch or update vote safely
        finalVote = await this.applyVoteSwitch(poll, existingVote, input, session);
      }

      const updatedPoll = (await this.repo.findPollById(pollObjectId, session)) || poll;
      return this.formatPollDto(updatedPoll, finalVote);
    });
  }

  private async applyVoteSwitch(
    poll: IPoll,
    existingVote: IPollVote,
    input: {
      choice: VoteChoice;
      reasonKey: string;
      explanation?: string | null;
    },
    session?: ClientSession
  ): Promise<IPollVote> {
    const oldChoice = existingVote.choice;
    const oldReasonKey = existingVote.reasonKey;
    const newChoice = input.choice;
    const newReasonKey = input.reasonKey;

    // If choice and reason didn't change, only update explanation if different
    if (oldChoice === newChoice && oldReasonKey === newReasonKey) {
      const cleanExplanation = input.explanation?.trim() || null;
      if (existingVote.explanation !== cleanExplanation) {
        const expUpdated = await this.repo.updateVoteExplanation(
          existingVote._id as mongoose.Types.ObjectId,
          cleanExplanation,
          session
        );
        return expUpdated || existingVote;
      }
      return existingVote;
    }

    // Atomic state-matching update on the vote document
    const updatedVote = await this.repo.atomicUpdateVote(
      existingVote._id as mongoose.Types.ObjectId,
      oldChoice,
      oldReasonKey,
      {
        choice: newChoice,
        reasonKey: newReasonKey,
        explanation: input.explanation?.trim() || null,
      },
      session
    );

    // If updatedVote is null, another concurrent request already transitioned this vote!
    if (!updatedVote) {
      // Re-read current vote without applying increments again to avoid double counting
      const currentVote = await this.repo.findUserVote(poll._id, existingVote.userId, session);
      return currentVote || existingVote;
    }

    // Build precise increment / decrement map
    const incObj: Record<string, number> = {};

    if (oldChoice !== newChoice) {
      if (oldChoice === 'LIKE') {
        incObj.likeCount = -1;
        incObj.dislikeCount = 1;
      } else {
        incObj.dislikeCount = -1;
        incObj.likeCount = 1;
      }
    }

    if (oldReasonKey !== newReasonKey || oldChoice !== newChoice) {
      const oldReasonField =
        oldChoice === 'LIKE' ? `likeReasons.${oldReasonKey}` : `dislikeReasons.${oldReasonKey}`;
      incObj[oldReasonField] = -1;

      const newReasonField =
        newChoice === 'LIKE' ? `likeReasons.${newReasonKey}` : `dislikeReasons.${newReasonKey}`;
      incObj[newReasonField] = (incObj[newReasonField] || 0) + 1;
    }

    if (Object.keys(incObj).length > 0) {
      await this.repo.applyVoteIncrements(poll._id, incObj, session);
    }

    return updatedVote;
  }

  async closePoll(pollId: string, userId: string, userRole: UserRole): Promise<PollResponseDto> {
    const poll = await this.repo.findPollById(pollId);
    if (!poll || poll.status === 'REMOVED') {
      throw new NotFoundError('Poll not found');
    }

    const isCreator = poll.createdBy.toString() === userId;
    const isStaff = userRole === USER_ROLES.ADMIN || userRole === USER_ROLES.MODERATOR;

    if (!isCreator && !isStaff) {
      throw new AuthorizationError('You are not authorized to close this poll');
    }

    const closed = await this.repo.closePoll(poll._id);
    return this.formatPollDto(closed!);
  }

  async reportPoll(
    pollId: string,
    userId: string,
    input: {
      reason: string;
      details?: string | null;
    }
  ): Promise<{ message: string; reportId: string }> {
    const pollObjectId = mongoose.Types.ObjectId.isValid(pollId)
      ? new mongoose.Types.ObjectId(pollId)
      : (pollId as any);
    const userObjectId = mongoose.Types.ObjectId.isValid(userId)
      ? new mongoose.Types.ObjectId(userId)
      : (userId as any);

    const poll = await this.repo.findPollById(pollObjectId);
    if (!poll || poll.status === 'REMOVED') {
      throw new NotFoundError('Poll not found');
    }

    // Check if user already submitted a report for this poll
    const existingReport = await this.repo.findReport(pollObjectId, userObjectId);
    if (existingReport) {
      throw new ValidationError('You have already submitted a moderation report for this poll');
    }

    try {
      const { report, newReportsCount } = await this.repo.createReport({
        pollId: pollObjectId,
        reportedBy: userObjectId,
        reason: input.reason.trim(),
        details: input.details?.trim() || null,
      });

      // Auto-flag as REPORTED if threshold reached (e.g. 5 reports)
      if (newReportsCount >= 5 && poll.status === 'ACTIVE') {
        await this.repo.updatePollStatus(pollObjectId, 'REPORTED');
      }

      return {
        message: 'Poll reported successfully and queued for moderation review',
        reportId: report._id.toString(),
      };
    } catch (err: any) {
      if (err?.code === 11000) {
        throw new ValidationError('You have already submitted a moderation report for this poll');
      }
      throw err;
    }
  }

  async moderatePoll(
    pollId: string,
    userRole: UserRole,
    input: { action: 'REMOVE' | 'CLOSE' | 'DISMISS_REPORTS' }
  ): Promise<PollResponseDto> {
    const isStaff = userRole === USER_ROLES.ADMIN || userRole === USER_ROLES.MODERATOR;
    if (!isStaff) {
      throw new AuthorizationError('Only moderators and admins can moderate polls');
    }

    const pollObjectId = new mongoose.Types.ObjectId(pollId);
    const poll = await this.repo.findPollById(pollObjectId);
    if (!poll) {
      throw new NotFoundError('Poll not found');
    }

    let updated: IPoll | null;

    switch (input.action) {
      case 'REMOVE':
        updated = await this.repo.updatePollStatus(pollObjectId, 'REMOVED');
        break;
      case 'CLOSE':
        updated = await this.repo.closePoll(pollObjectId);
        break;
      case 'DISMISS_REPORTS':
        updated = await this.repo.resetPollReports(pollObjectId, 'ACTIVE');
        break;
    }

    return this.formatPollDto(updated || poll);
  }
}

export const pollService = new PollService();
