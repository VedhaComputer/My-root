import mongoose, { ClientSession } from 'mongoose';
import { pollRepository, PollRepository } from './repository';
import { IPoll, IPollVote, IPollPerson, IPollQuestion, VoteChoice, QuestionType } from './poll.model';
import { NotFoundError, ValidationError, AuthorizationError } from '../../shared/errors/AppError';
import { USER_ROLES, UserRole } from '../../shared/constants';

export interface ReasonBreakdownItem {
  key: string;
  count: number;
  percentage: number;
}

export interface PollPersonDto {
  id: string;
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
  verificationStatus?: string;
}

export interface UserVoteDto {
  questionId: string;
  personId?: string | null;
  choice: VoteChoice;
  reasonKey: string;
  explanation?: string | null;
  updatedAt: string;
}

export interface PollQuestionDto {
  id: string;
  text: string;
  personId?: string | null;
  questionType: QuestionType;
  options?: Array<{ key: string; labelEn: string; labelHi: string }>;
  likeCount: number;
  dislikeCount: number;
  totalVotes: number;
  likePercentage: number;
  dislikePercentage: number;
  likeReasons: ReasonBreakdownItem[];
  dislikeReasons: ReasonBreakdownItem[];
  userVote?: UserVoteDto | null;
}

export interface PollResponseDto {
  id: string;
  purpose?: string | null;
  category?: string | null;
  people: PollPersonDto[];
  questions: PollQuestionDto[];

  // Legacy / top-level fields
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
  userVote?: UserVoteDto | null;
  userVotes?: Record<string, UserVoteDto>;
  createdAt: string;
  updatedAt: string;
}

export class PollService {
  constructor(private readonly repo: PollRepository = pollRepository) {}

  private extractReasonBreakdown(
    rawMap: Record<string, number> | Map<string, number> | undefined,
    totalBase: number
  ): ReasonBreakdownItem[] {
    const rawObj: Record<string, number> =
      rawMap instanceof Map
        ? Object.fromEntries(rawMap)
        : (rawMap as Record<string, number>) || {};

    return Object.entries(rawObj)
      .map(([key, count]) => ({
        key,
        count,
        percentage: totalBase > 0 ? Number(((count / totalBase) * 100).toFixed(1)) : 0,
      }))
      .sort((a, b) => b.count - a.count);
  }

  public formatPollDto(
    poll: IPoll,
    userVotesInput?: IPollVote[] | IPollVote | null
  ): PollResponseDto {
    const totalVotes = poll.totalVotes || (poll.likeCount + poll.dislikeCount) || 0;
    const likeCount = poll.likeCount || 0;
    const dislikeCount = poll.dislikeCount || 0;

    const likePercentage = totalVotes > 0 ? Number(((likeCount / totalVotes) * 100).toFixed(1)) : 0;
    const dislikePercentage = totalVotes > 0 ? Number(((dislikeCount / totalVotes) * 100).toFixed(1)) : 0;

    const likeReasons = this.extractReasonBreakdown(poll.likeReasons, likeCount);
    const dislikeReasons = this.extractReasonBreakdown(poll.dislikeReasons, dislikeCount);

    // Normalize user votes map
    const userVotesList: IPollVote[] = Array.isArray(userVotesInput)
      ? userVotesInput
      : userVotesInput
      ? [userVotesInput]
      : [];

    const userVotesMap: Record<string, UserVoteDto> = {};
    for (const v of userVotesList) {
      const qKey = v.questionId || 'default';
      userVotesMap[qKey] = {
        questionId: qKey,
        personId: v.personId || null,
        choice: v.choice,
        reasonKey: v.reasonKey,
        explanation: v.explanation,
        updatedAt: v.updatedAt ? v.updatedAt.toISOString() : new Date().toISOString(),
      };
    }

    // Format People array (synthesize if empty for legacy polls)
    let peopleDto: PollPersonDto[] = [];
    if (poll.people && poll.people.length > 0) {
      peopleDto = poll.people.map((p) => ({
        id: p._id ? p._id.toString() : p.id || '',
        name: p.name,
        role: p.role,
        designation: p.designation || p.role,
        officeContext: p.officeContext,
        placeId: p.placeId || poll.placeId,
        placeName: p.placeName || poll.placeName,
        targetEntityId: p.targetEntityId || poll.targetEntityId,
        photoUrl: p.photoUrl || null,
        workBackground: p.workBackground || null,
        publicServiceHistory: p.publicServiceHistory || null,
        education: p.education || null,
        achievements: p.achievements || null,
        casteCommunity: p.casteCommunity || null,
        religion: p.religion || null,
        bio: p.bio || null,
        sourceReference: p.sourceReference || null,
        verificationStatus: p.verificationStatus || 'UNVERIFIED',
      }));
    } else {
      peopleDto = [
        {
          id: 'p0',
          name: poll.personName,
          role: poll.personRole,
          designation: poll.personRole,
          officeContext: null,
          placeId: poll.placeId,
          placeName: poll.placeName,
          targetEntityId: poll.targetEntityId,
          photoUrl: poll.photoUrl,
          workBackground: (poll as any).workBackground || null,
          publicServiceHistory: (poll as any).publicServiceHistory || null,
          education: (poll as any).education || null,
          achievements: (poll as any).achievements || null,
          casteCommunity: (poll as any).casteCommunity || null,
          religion: (poll as any).religion || null,
          bio: (poll as any).bio || null,
          sourceReference: (poll as any).sourceReference || null,
          verificationStatus: (poll as any).verificationStatus || 'UNVERIFIED',
        },
      ];
    }

    // Format Questions array (synthesize if empty for legacy polls)
    let questionsDto: PollQuestionDto[] = [];
    if (poll.questions && poll.questions.length > 0) {
      questionsDto = poll.questions.map((q) => {
        const qId = q._id ? q._id.toString() : q.id || '';
        const qTotal = q.totalVotes || (q.likeCount + q.dislikeCount) || 0;
        const qLikes = q.likeCount || 0;
        const qDislikes = q.dislikeCount || 0;
        const qLikePct = qTotal > 0 ? Number(((qLikes / qTotal) * 100).toFixed(1)) : 0;
        const qDislikePct = qTotal > 0 ? Number(((qDislikes / qTotal) * 100).toFixed(1)) : 0;
        const qLikeReasons = this.extractReasonBreakdown(q.likeReasons, qLikes);
        const qDislikeReasons = this.extractReasonBreakdown(q.dislikeReasons, qDislikes);

        const matchingVote = userVotesMap[qId] || userVotesMap['default'] || null;

        return {
          id: qId,
          text: q.text,
          personId: q.personId || null,
          questionType: q.questionType || 'LIKE_DISLIKE',
          options: q.options || [],
          likeCount: qLikes,
          dislikeCount: qDislikes,
          totalVotes: qTotal,
          likePercentage: qLikePct,
          dislikePercentage: qDislikePct,
          likeReasons: qLikeReasons,
          dislikeReasons: qDislikeReasons,
          userVote: matchingVote,
        };
      });
    } else {
      const singleVote = userVotesList[0]
        ? {
            questionId: 'q0',
            personId: 'p0',
            choice: userVotesList[0].choice,
            reasonKey: userVotesList[0].reasonKey,
            explanation: userVotesList[0].explanation,
            updatedAt: userVotesList[0].updatedAt
              ? userVotesList[0].updatedAt.toISOString()
              : new Date().toISOString(),
          }
        : null;

      questionsDto = [
        {
          id: 'q0',
          text: poll.question,
          personId: 'p0',
          questionType: 'LIKE_DISLIKE',
          likeCount,
          dislikeCount,
          totalVotes,
          likePercentage,
          dislikePercentage,
          likeReasons,
          dislikeReasons,
          userVote: singleVote,
        },
      ];
    }

    // Determine primary userVote for legacy backward compatibility
    const primaryVote = questionsDto[0]?.userVote || userVotesList[0]
      ? {
          questionId: questionsDto[0]?.id || 'default',
          personId: questionsDto[0]?.personId || null,
          choice: (userVotesList[0] || questionsDto[0]?.userVote!).choice,
          reasonKey: (userVotesList[0] || questionsDto[0]?.userVote!).reasonKey,
          explanation: (userVotesList[0] || questionsDto[0]?.userVote!).explanation,
          updatedAt: userVotesList[0]?.updatedAt
            ? userVotesList[0].updatedAt.toISOString()
            : new Date().toISOString(),
        }
      : null;

    return {
      id: poll._id.toString(),
      purpose: poll.purpose || null,
      category: poll.category || null,
      people: peopleDto,
      questions: questionsDto,

      // Legacy fields
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
      userVote: primaryVote,
      userVotes: userVotesMap,
      createdAt: poll.createdAt.toISOString(),
      updatedAt: poll.updatedAt.toISOString(),
    };
  }

  async createPoll(
    userId: string,
    userName: string,
    input: {
      purpose?: string | null;
      category?: string | null;
      people?: Array<{
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
      }>;
      questions?: Array<{
        text: string;
        personId?: string | null;
        questionType?: QuestionType;
        options?: Array<{ key: string; labelEn: string; labelHi: string }>;
      }>;
      // Legacy fields
      personName?: string;
      personRole?: string | null;
      placeId?: string | null;
      placeName?: string | null;
      targetEntityId?: string | null;
      question?: string;
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
      startTime?: string | null;
      endTime?: string | null;
      durationDays?: number | null;
    },
    userRole?: UserRole
  ): Promise<PollResponseDto> {
    const isStaff =
      userRole === USER_ROLES.ADMIN ||
      userRole === USER_ROLES.MODERATOR ||
      userRole === USER_ROLES.REVIEWER;

    const startTime = input.startTime ? new Date(input.startTime) : new Date();
    if (isNaN(startTime.getTime())) {
      throw new ValidationError('Invalid start time date format');
    }

    let endTime: Date | null = null;
    if (input.endTime) {
      endTime = new Date(input.endTime);
      if (isNaN(endTime.getTime())) {
        throw new ValidationError('Invalid end time date format');
      }
    } else if (input.durationDays && input.durationDays > 0) {
      endTime = new Date(startTime.getTime() + input.durationDays * 24 * 60 * 60 * 1000);
    }

    if (endTime && endTime.getTime() <= startTime.getTime()) {
      throw new ValidationError('End time must be after start time');
    }

    // Process People
    const peopleList: Array<Partial<IPollPerson>> = [];
    if (input.people && input.people.length > 0) {
      for (const p of input.people) {
        const candidateStatus = p.verificationStatus || 'UNVERIFIED';
        if (candidateStatus === 'VERIFIED' && !isStaff) {
          throw new AuthorizationError(
            'Only authorized administrative staff can grant VERIFIED profile verification status'
          );
        }

        peopleList.push({
          _id: new mongoose.Types.ObjectId(),
          name: p.name.trim(),
          role: p.role?.trim() || null,
          designation: p.designation?.trim() || p.role?.trim() || null,
          officeContext: p.officeContext?.trim() || null,
          placeId: p.placeId?.trim() || input.placeId?.trim() || null,
          placeName: p.placeName?.trim() || input.placeName?.trim() || null,
          targetEntityId: p.targetEntityId?.trim() || null,
          photoUrl: p.photoUrl?.trim() || null,
          workBackground: p.workBackground?.trim() || null,
          publicServiceHistory: p.publicServiceHistory?.trim() || null,
          education: p.education?.trim() || null,
          achievements: p.achievements?.trim() || null,
          casteCommunity: p.casteCommunity?.trim() || null,
          religion: p.religion?.trim() || null,
          bio: p.bio?.trim() || null,
          sourceReference: p.sourceReference?.trim() || null,
          verificationStatus: candidateStatus,
        });
      }
    } else if (input.personName && input.personName.trim().length >= 2) {
      const candidateStatus = input.verificationStatus || 'UNVERIFIED';
      if (candidateStatus === 'VERIFIED' && !isStaff) {
        throw new AuthorizationError(
          'Only authorized administrative staff can grant VERIFIED profile verification status'
        );
      }

      peopleList.push({
        _id: new mongoose.Types.ObjectId(),
        name: input.personName.trim(),
        role: input.personRole?.trim() || null,
        designation: input.personRole?.trim() || null,
        officeContext: null,
        placeId: input.placeId?.trim() || null,
        placeName: input.placeName?.trim() || null,
        targetEntityId: input.targetEntityId?.trim() || null,
        photoUrl: input.photoUrl?.trim() || null,
        workBackground: input.workBackground?.trim() || null,
        publicServiceHistory: input.publicServiceHistory?.trim() || null,
        education: input.education?.trim() || null,
        achievements: input.achievements?.trim() || null,
        casteCommunity: input.casteCommunity?.trim() || null,
        religion: input.religion?.trim() || null,
        bio: input.bio?.trim() || null,
        sourceReference: input.sourceReference?.trim() || null,
        verificationStatus: candidateStatus,
      });
    } else {
      throw new ValidationError('At least one evaluated person must be provided');
    }

    // Process Questions
    const questionsList: Array<Partial<IPollQuestion>> = [];
    if (input.questions && input.questions.length > 0) {
      for (const q of input.questions) {
        questionsList.push({
          _id: new mongoose.Types.ObjectId(),
          text: q.text.trim(),
          personId: q.personId?.trim() || null,
          questionType: q.questionType || 'LIKE_DISLIKE',
          options: q.options || [],
          likeCount: 0,
          dislikeCount: 0,
          totalVotes: 0,
          likeReasons: {},
          dislikeReasons: {},
        });
      }
    } else if (input.question && input.question.trim().length >= 5) {
      questionsList.push({
        _id: new mongoose.Types.ObjectId(),
        text: input.question.trim(),
        personId: peopleList[0]?._id?.toString() || null,
        questionType: 'LIKE_DISLIKE',
        options: [],
        likeCount: 0,
        dislikeCount: 0,
        totalVotes: 0,
        likeReasons: {},
        dislikeReasons: {},
      });
    } else {
      throw new ValidationError('At least one poll question must be provided');
    }

    // Top-level legacy fallbacks
    const primaryPerson = peopleList[0]!;
    const primaryQuestion = questionsList[0]!;

    const poll = await this.repo.createPoll({
      purpose: input.purpose?.trim() || null,
      category: input.category?.trim() || null,
      people: peopleList as IPollPerson[],
      questions: questionsList as IPollQuestion[],
      personName: input.personName?.trim() || primaryPerson.name,
      personRole: input.personRole?.trim() || primaryPerson.role || primaryPerson.designation || null,
      placeId: input.placeId?.trim() || primaryPerson.placeId || null,
      placeName: input.placeName?.trim() || primaryPerson.placeName || null,
      targetEntityId: input.targetEntityId?.trim() || primaryPerson.targetEntityId || null,
      question: input.question?.trim() || primaryQuestion.text,
      description: input.description?.trim() || null,
      photoUrl: input.photoUrl?.trim() || primaryPerson.photoUrl || null,
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

    let userVotes: IPollVote[] = [];
    if (currentUserId && mongoose.Types.ObjectId.isValid(currentUserId)) {
      userVotes = await this.repo.findUserVotesForPoll(poll._id, currentUserId);
    }

    return this.formatPollDto(poll, userVotes);
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
      filter.$or = [
        { personName: { $regex: query.personName.trim(), $options: 'i' } },
        { 'people.name': { $regex: query.personName.trim(), $options: 'i' } },
      ];
    }
    if (query.search) {
      const term = query.search.trim();
      filter.$or = [
        { personName: { $regex: term, $options: 'i' } },
        { question: { $regex: term, $options: 'i' } },
        { purpose: { $regex: term, $options: 'i' } },
        { category: { $regex: term, $options: 'i' } },
        { personRole: { $regex: term, $options: 'i' } },
        { placeName: { $regex: term, $options: 'i' } },
        { 'people.name': { $regex: term, $options: 'i' } },
        { 'people.role': { $regex: term, $options: 'i' } },
        { 'people.designation': { $regex: term, $options: 'i' } },
        { 'questions.text': { $regex: term, $options: 'i' } },
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
      questionId?: string | null;
      personId?: string | null;
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

      const now = new Date();

      // Check future-start rule: voting rejected before startTime
      if (poll.startTime && now.getTime() < poll.startTime.getTime()) {
        throw new ValidationError(
          `This poll has not started yet. Voting begins on ${poll.startTime.toISOString()}`
        );
      }

      // Check expiry: voting rejected after endTime
      if (poll.status === 'ACTIVE' && poll.endTime && now.getTime() > poll.endTime.getTime()) {
        poll.status = 'CLOSED';
        await poll.save({ session });
      }

      if (poll.status !== 'ACTIVE') {
        throw new ValidationError('This poll is closed and no longer accepting votes');
      }

      // Resolve target question
      let targetQuestionId = 'default';
      let qIndex = -1;

      if (poll.questions && poll.questions.length > 0) {
        if (input.questionId) {
          qIndex = poll.questions.findIndex((q) => q._id.toString() === input.questionId);
          if (qIndex === -1) {
            throw new NotFoundError('Question not found in this poll');
          }
          targetQuestionId = poll.questions[qIndex]._id.toString();
        } else {
          // Default to the first question
          qIndex = 0;
          targetQuestionId = poll.questions[0]._id.toString();
        }
      } else if (input.questionId) {
        targetQuestionId = input.questionId;
      }

      // Resolve target person
      let targetPersonId = input.personId?.trim() || null;
      if (!targetPersonId) {
        if (qIndex >= 0 && poll.questions[qIndex]?.personId) {
          targetPersonId = poll.questions[qIndex].personId || null;
        } else if (poll.people && poll.people.length > 0) {
          targetPersonId = poll.people[0]._id.toString();
        }
      }

      const existingVote = await this.repo.findUserVote(
        pollObjectId,
        userObjectId,
        targetQuestionId,
        session
      );

      let finalVote: IPollVote;

      if (!existingVote) {
        // User has not voted on this question yet: Attempt to create new vote
        try {
          finalVote = await this.repo.createVote(
            {
              pollId: pollObjectId,
              userId: userObjectId,
              questionId: targetQuestionId,
              personId: targetPersonId,
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

          const incObj: Record<string, number> = {};

          if (qIndex >= 0) {
            incObj[`questions.${qIndex}.totalVotes`] = 1;
            incObj[`questions.${qIndex}.${incField}`] = 1;
            incObj[`questions.${qIndex}.${reasonField}`] = 1;
          }

          // Top-level counters synchronize with question 0 or legacy single question
          if (qIndex <= 0) {
            incObj.totalVotes = 1;
            incObj[incField] = 1;
            incObj[reasonField] = 1;
          }

          await this.repo.applyVoteIncrements(pollObjectId, incObj, session);
        } catch (err: any) {
          // Handle race condition on duplicate initial submission (code 11000)
          if (err?.code === 11000) {
            const createdVote = await this.repo.findUserVote(
              pollObjectId,
              userObjectId,
              targetQuestionId,
              session
            );
            if (!createdVote) {
              throw err;
            }
            if (createdVote.choice === input.choice && createdVote.reasonKey === input.reasonKey) {
              finalVote = createdVote;
            } else {
              finalVote = await this.applyVoteSwitch(poll, createdVote, input, qIndex, session);
            }
          } else {
            throw err;
          }
        }
      } else {
        // Existing vote found: switch or update vote safely on this question
        finalVote = await this.applyVoteSwitch(poll, existingVote, input, qIndex, session);
      }

      const updatedPoll = (await this.repo.findPollById(pollObjectId, session)) || poll;
      const allUserVotes = await this.repo.findUserVotesForPoll(pollObjectId, userObjectId, session);
      return this.formatPollDto(updatedPoll, allUserVotes);
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
    qIndex: number,
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
      const currentVote = await this.repo.findUserVote(
        poll._id,
        existingVote.userId,
        existingVote.questionId,
        session
      );
      return currentVote || existingVote;
    }

    // Build precise increment / decrement map
    const incObj: Record<string, number> = {};

    if (oldChoice !== newChoice) {
      if (oldChoice === 'LIKE') {
        if (qIndex >= 0) {
          incObj[`questions.${qIndex}.likeCount`] = -1;
          incObj[`questions.${qIndex}.dislikeCount`] = 1;
        }
        if (qIndex <= 0) {
          incObj.likeCount = -1;
          incObj.dislikeCount = 1;
        }
      } else {
        if (qIndex >= 0) {
          incObj[`questions.${qIndex}.dislikeCount`] = -1;
          incObj[`questions.${qIndex}.likeCount`] = 1;
        }
        if (qIndex <= 0) {
          incObj.dislikeCount = -1;
          incObj.likeCount = 1;
        }
      }
    }

    if (oldReasonKey !== newReasonKey || oldChoice !== newChoice) {
      const oldReasonField =
        oldChoice === 'LIKE' ? `likeReasons.${oldReasonKey}` : `dislikeReasons.${oldReasonKey}`;
      const newReasonField =
        newChoice === 'LIKE' ? `likeReasons.${newReasonKey}` : `dislikeReasons.${newReasonKey}`;

      if (qIndex >= 0) {
        incObj[`questions.${qIndex}.${oldReasonField}`] = -1;
        incObj[`questions.${qIndex}.${newReasonField}`] =
          (incObj[`questions.${qIndex}.${newReasonField}`] || 0) + 1;
      }
      if (qIndex <= 0) {
        incObj[oldReasonField] = -1;
        incObj[newReasonField] = (incObj[newReasonField] || 0) + 1;
      }
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
    input: {
      action: 'REMOVE' | 'CLOSE' | 'DISMISS_REPORTS' | 'UPDATE_VERIFICATION';
      personId?: string;
      verificationStatus?: 'UNVERIFIED' | 'SELF_CLAIMED' | 'DOCUMENTED' | 'VERIFIED';
    }
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
      case 'UPDATE_VERIFICATION':
        if (!input.verificationStatus) {
          throw new ValidationError('verificationStatus is required for UPDATE_VERIFICATION action');
        }
        updated = await this.repo.updatePersonVerificationStatus(
          pollObjectId,
          input.personId || null,
          input.verificationStatus
        );
        break;
    }

    return this.formatPollDto(updated || poll);
  }
}

export const pollService = new PollService();
