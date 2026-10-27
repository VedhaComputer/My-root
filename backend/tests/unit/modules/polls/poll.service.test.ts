import mongoose from 'mongoose';
import { PollService } from '../../../../src/modules/polls/service';
import { PollRepository } from '../../../../src/modules/polls/repository';
import { IPoll, IPollVote } from '../../../../src/modules/polls/poll.model';
import { USER_ROLES } from '../../../../src/shared/constants';
import { ValidationError, AuthorizationError, NotFoundError } from '../../../../src/shared/errors/AppError';

describe('PollService (Unit Tests)', () => {
  let mockRepo: jest.Mocked<PollRepository>;
  let service: PollService;

  beforeEach(() => {
    mockRepo = {
      createPoll: jest.fn(),
      findPollById: jest.fn(),
      findPolls: jest.fn(),
      findUserVote: jest.fn(),
      findUserVotesForPoll: jest.fn(),
      createVote: jest.fn(),
      updateVote: jest.fn(),
      atomicUpdateVote: jest.fn(),
      updateVoteExplanation: jest.fn(),
      applyVoteIncrements: jest.fn(),
      closePoll: jest.fn(),
      createReport: jest.fn(),
      findReport: jest.fn(),
      updatePollStatus: jest.fn(),
      resetPollReports: jest.fn(),
      withTransaction: jest.fn(async (cb) => cb()),
      ensureIndexesSafe: jest.fn().mockResolvedValue(undefined),
      supportsTransactions: jest.fn().mockReturnValue(true),
    } as any;
    service = new PollService(mockRepo);
  });

  const samplePoll: IPoll = {
    _id: new mongoose.Types.ObjectId(),
    personName: 'Shri Ram Sharma',
    personRole: 'Sarpanch',
    placeId: 'PL_VIL_amer',
    placeName: 'Amer Village',
    targetEntityId: 'sarpanch',
    question: 'Opinion on Ram Sharma?',
    description: null,
    photoUrl: null,
    status: 'ACTIVE',
    startTime: new Date('2026-01-01'),
    endTime: null,
    createdBy: new mongoose.Types.ObjectId(),
    creatorName: 'Admin',
    likeCount: 75,
    dislikeCount: 25,
    totalVotes: 100,
    likeReasons: { work_performance: 50, helping_nature: 25 },
    dislikeReasons: { promises_unfulfilled: 25 },
    reportsCount: 0,
    people: [],
    questions: [],
    createdAt: new Date('2026-01-01'),
    updatedAt: new Date('2026-01-01'),
  } as any;

  test('formatPollDto accurately calculates percentages with zero-vote safety', () => {
    const formatted = service.formatPollDto(samplePoll);
    expect(formatted.likePercentage).toBe(75);
    expect(formatted.dislikePercentage).toBe(25);
    expect(formatted.totalVotes).toBe(100);

    // Verify reason percentages
    expect(formatted.likeReasons[0].key).toBe('work_performance');
    expect(formatted.likeReasons[0].count).toBe(50);
    expect(formatted.likeReasons[0].percentage).toBe(66.7); // 50 / 75 = 66.7%

    // Zero vote safety
    const zeroPoll = { ...samplePoll, likeCount: 0, dislikeCount: 0, totalVotes: 0 } as any;
    const zeroFormatted = service.formatPollDto(zeroPoll);
    expect(zeroFormatted.likePercentage).toBe(0);
    expect(zeroFormatted.dislikePercentage).toBe(0);
  });

  test('castVote rejects voting on an already closed poll', async () => {
    mockRepo.findPollById.mockResolvedValue({
      ...samplePoll,
      status: 'CLOSED',
    } as any);

    await expect(
      service.castVote(samplePoll._id.toString(), 'user-1', {
        choice: 'LIKE',
        reasonKey: 'work_performance',
      })
    ).rejects.toThrow(ValidationError);
  });

  test('closePoll permits creator or admin and rejects unauthorized users', async () => {
    const creatorId = new mongoose.Types.ObjectId();
    const otherUserId = new mongoose.Types.ObjectId();

    mockRepo.findPollById.mockResolvedValue({
      ...samplePoll,
      createdBy: creatorId,
    } as any);

    mockRepo.closePoll.mockResolvedValue({
      ...samplePoll,
      status: 'CLOSED',
    } as any);

    // Other non-admin user attempts close -> rejected
    await expect(
      service.closePoll('poll-1', otherUserId.toString(), USER_ROLES.CONTRIBUTOR)
    ).rejects.toThrow(AuthorizationError);

    // Creator attempts close -> allowed
    const creatorRes = await service.closePoll('poll-1', creatorId.toString(), USER_ROLES.CONTRIBUTOR);
    expect(creatorRes.status).toBe('CLOSED');

    // Admin attempts close -> allowed
    const adminRes = await service.closePoll('poll-1', otherUserId.toString(), USER_ROLES.ADMIN);
    expect(adminRes.status).toBe('CLOSED');
  });

  describe('Multi-Person and Purpose/Designation Features', () => {
    test('creates multi-person poll with separate purpose, roles, and office contexts', async () => {
      const creatorId = new mongoose.Types.ObjectId().toString();
      const personId1 = new mongoose.Types.ObjectId();
      const personId2 = new mongoose.Types.ObjectId();
      const qId1 = new mongoose.Types.ObjectId();
      const qId2 = new mongoose.Types.ObjectId();

      mockRepo.createPoll.mockImplementation(async (data: any) => ({
        ...data,
        _id: new mongoose.Types.ObjectId(),
        createdAt: new Date(),
        updatedAt: new Date(),
      }));

      const res = await service.createPoll(creatorId, 'PollCreator', {
        purpose: 'Gram Panchayat Leadership Assessment 2026',
        category: 'GOVERNANCE',
        people: [
          {
            name: 'Devi Lal',
            role: 'Sarpanch',
            designation: 'Panchayat President',
            officeContext: 'Current Term 2021-2026',
            placeName: 'Amer Village',
          },
          {
            name: 'Sunita Sharma',
            role: 'Ward Member',
            designation: 'Ward 4 Representative',
            officeContext: 'Candidate / Challenger',
            placeName: 'Amer Village',
          },
        ],
        questions: [
          {
            text: 'Do you approve of Devi Lal as Sarpanch?',
            personId: personId1.toString(),
            questionType: 'LIKE_DISLIKE',
          },
          {
            text: 'Do you approve of Sunita Sharma for future leadership?',
            personId: personId2.toString(),
            questionType: 'LIKE_DISLIKE',
          },
        ],
        durationDays: 180, // 6 months (longer than 3 months)
      });

      expect(res.purpose).toBe('Gram Panchayat Leadership Assessment 2026');
      expect(res.category).toBe('GOVERNANCE');
      expect(res.people).toHaveLength(2);
      expect(res.people[0].name).toBe('Devi Lal');
      expect(res.people[0].role).toBe('Sarpanch');
      expect(res.people[0].officeContext).toBe('Current Term 2021-2026');
      expect(res.people[1].name).toBe('Sunita Sharma');
      expect(res.people[1].officeContext).toBe('Candidate / Challenger');

      // Top-level compatibility fallbacks populated from person 0
      expect(res.personName).toBe('Devi Lal');
      expect(res.personRole).toBe('Sarpanch');
      expect(res.questions).toHaveLength(2);
      expect(res.question).toBe('Do you approve of Devi Lal as Sarpanch?');
    });

    test('supports flexible durations exceeding 3 months and years', async () => {
      const creatorId = new mongoose.Types.ObjectId().toString();

      mockRepo.createPoll.mockImplementation(async (data: any) => ({
        ...data,
        _id: new mongoose.Types.ObjectId(),
        createdAt: new Date(),
        updatedAt: new Date(),
      }));

      // 5-year duration (1825 days)
      const res5Years = await service.createPoll(creatorId, 'Creator', {
        personName: 'Hon. Member of Parliament',
        personRole: 'MP',
        question: 'Rate the 5-year performance of the Member of Parliament',
        durationDays: 1825,
      });

      const start = new Date(res5Years.startTime).getTime();
      const end = new Date(res5Years.endTime!).getTime();
      const diffDays = Math.round((end - start) / (24 * 60 * 60 * 1000));
      expect(diffDays).toBe(1825);
    });

    test('rejects creation when endTime is before or equal to startTime', async () => {
      const creatorId = new mongoose.Types.ObjectId().toString();

      await expect(
        service.createPoll(creatorId, 'Creator', {
          personName: 'Test Person',
          question: 'Test question valid length?',
          startTime: '2026-06-01T00:00:00.000Z',
          endTime: '2026-05-01T00:00:00.000Z',
        })
      ).rejects.toThrow(ValidationError);
    });
  });

  describe('Multiple Independent Questions and Answer Uniqueness', () => {
    const q1Id = new mongoose.Types.ObjectId();
    const q2Id = new mongoose.Types.ObjectId();
    const p1Id = new mongoose.Types.ObjectId();
    const p2Id = new mongoose.Types.ObjectId();

    const multiQuestionPoll: IPoll = {
      _id: new mongoose.Types.ObjectId(),
      purpose: 'Bilateral Comparison',
      category: 'CIVIC',
      personName: 'Candidate A',
      question: 'Question 1 for Candidate A?',
      status: 'ACTIVE',
      startTime: new Date('2026-01-01'),
      endTime: new Date('2027-01-01'),
      createdBy: new mongoose.Types.ObjectId(),
      likeCount: 1,
      dislikeCount: 0,
      totalVotes: 1,
      likeReasons: { work_performance: 1 },
      dislikeReasons: {},
      people: [
        {
          _id: p1Id,
          name: 'Candidate A',
          role: 'MLA',
          designation: 'Legislative Assembly Member',
        },
        {
          _id: p2Id,
          name: 'Candidate B',
          role: 'Social Worker',
          designation: 'Citizen Representative',
        },
      ],
      questions: [
        {
          _id: q1Id,
          text: 'Question 1: Does Candidate A fulfill promises?',
          personId: p1Id.toString(),
          questionType: 'LIKE_DISLIKE',
          likeCount: 1,
          dislikeCount: 0,
          totalVotes: 1,
          likeReasons: { promises_fulfilled: 1 },
          dislikeReasons: {},
        },
        {
          _id: q2Id,
          text: 'Question 2: Does Candidate B exhibit transparency?',
          personId: p2Id.toString(),
          questionType: 'LIKE_DISLIKE',
          likeCount: 0,
          dislikeCount: 0,
          totalVotes: 0,
          likeReasons: {},
          dislikeReasons: {},
        },
      ],
      createdAt: new Date('2026-01-01'),
      updatedAt: new Date('2026-01-01'),
    } as any;

    test('voter can answer question 2 independently after answering question 1', async () => {
      const userId = new mongoose.Types.ObjectId().toString();

      mockRepo.findPollById.mockResolvedValue(multiQuestionPoll);
      // Voter has no vote yet on Question 2
      mockRepo.findUserVote.mockResolvedValue(null);

      const createdVoteQ2: IPollVote = {
        _id: new mongoose.Types.ObjectId(),
        pollId: multiQuestionPoll._id,
        userId: new mongoose.Types.ObjectId(userId),
        questionId: q2Id.toString(),
        personId: p2Id.toString(),
        choice: 'LIKE',
        reasonKey: 'transparency',
        explanation: 'Very transparent and accessible',
        createdAt: new Date(),
        updatedAt: new Date(),
      } as any;

      mockRepo.createVote.mockResolvedValue(createdVoteQ2);
      mockRepo.findUserVotesForPoll.mockResolvedValue([createdVoteQ2]);

      const res = await service.castVote(multiQuestionPoll._id.toString(), userId, {
        questionId: q2Id.toString(),
        choice: 'LIKE',
        reasonKey: 'transparency',
        explanation: 'Very transparent and accessible',
      });

      expect(mockRepo.createVote).toHaveBeenCalledWith(
        expect.objectContaining({
          questionId: q2Id.toString(),
          choice: 'LIKE',
          reasonKey: 'transparency',
        }),
        undefined
      );

      // Increments applied to Question 2 index (1) without altering Question 1
      expect(mockRepo.applyVoteIncrements).toHaveBeenCalledWith(
        multiQuestionPoll._id,
        expect.objectContaining({
          'questions.1.totalVotes': 1,
          'questions.1.likeCount': 1,
          'questions.1.likeReasons.transparency': 1,
        }),
        undefined
      );
    });

    test('duplicate answer on same question switches vote on that question without affecting other questions', async () => {
      const userId = new mongoose.Types.ObjectId().toString();

      mockRepo.findPollById.mockResolvedValue(multiQuestionPoll);

      const existingVoteQ1: IPollVote = {
        _id: new mongoose.Types.ObjectId(),
        pollId: multiQuestionPoll._id,
        userId: new mongoose.Types.ObjectId(userId),
        questionId: q1Id.toString(),
        personId: p1Id.toString(),
        choice: 'LIKE',
        reasonKey: 'promises_fulfilled',
        createdAt: new Date(),
        updatedAt: new Date(),
      } as any;

      // Existing vote found on Question 1
      mockRepo.findUserVote.mockResolvedValue(existingVoteQ1);

      const switchedVoteQ1: IPollVote = {
        ...existingVoteQ1,
        choice: 'DISLIKE',
        reasonKey: 'promises_unfulfilled',
      } as any;

      mockRepo.atomicUpdateVote.mockResolvedValue(switchedVoteQ1);
      mockRepo.findUserVotesForPoll.mockResolvedValue([switchedVoteQ1]);

      await service.castVote(multiQuestionPoll._id.toString(), userId, {
        questionId: q1Id.toString(),
        choice: 'DISLIKE',
        reasonKey: 'promises_unfulfilled',
      });

      // Atomic compare-and-swap targeted specifically at existing choice/reason
      expect(mockRepo.atomicUpdateVote).toHaveBeenCalledWith(
        existingVoteQ1._id,
        'LIKE',
        'promises_fulfilled',
        expect.objectContaining({
          choice: 'DISLIKE',
          reasonKey: 'promises_unfulfilled',
        }),
        undefined
      );

      // Verified Question 1 index (0) increments/decrements
      expect(mockRepo.applyVoteIncrements).toHaveBeenCalledWith(
        multiQuestionPoll._id,
        expect.objectContaining({
          'questions.0.likeCount': -1,
          'questions.0.dislikeCount': 1,
          'questions.0.likeReasons.promises_fulfilled': -1,
          'questions.0.dislikeReasons.promises_unfulfilled': 1,
        }),
        undefined
      );
    });
  });

  describe('Start and End Time Enforcement', () => {
    test('rejects voting before poll start time with descriptive message', async () => {
      const futureStartPoll: IPoll = {
        ...samplePoll,
        status: 'ACTIVE',
        startTime: new Date(Date.now() + 24 * 60 * 60 * 1000), // starts tomorrow
      } as any;

      mockRepo.findPollById.mockResolvedValue(futureStartPoll);

      await expect(
        service.castVote(futureStartPoll._id.toString(), 'user-1', {
          choice: 'LIKE',
          reasonKey: 'work_performance',
        })
      ).rejects.toThrow(/This poll has not started yet/);
    });

    test('rejects voting after poll end time and transitions poll to CLOSED', async () => {
      const expiredPoll: IPoll = {
        ...samplePoll,
        status: 'ACTIVE',
        startTime: new Date('2025-01-01'),
        endTime: new Date(Date.now() - 3600000), // ended 1 hour ago
        save: jest.fn().mockResolvedValue(true),
      } as any;

      mockRepo.findPollById.mockResolvedValue(expiredPoll);

      await expect(
        service.castVote(expiredPoll._id.toString(), 'user-1', {
          choice: 'LIKE',
          reasonKey: 'work_performance',
        })
      ).rejects.toThrow(/This poll is closed/);

      expect(expiredPoll.status).toBe('CLOSED');
      expect(expiredPoll.save).toHaveBeenCalled();
    });
  });

  describe('Legacy Single-Person Compatibility and Reporting', () => {
    test('synthesizes people and questions arrays for legacy documents without them', () => {
      const legacyDoc: IPoll = {
        _id: new mongoose.Types.ObjectId(),
        personName: 'Elderly Leader',
        personRole: 'Social Worker',
        placeId: 'PL_DELHI',
        placeName: 'Delhi',
        targetEntityId: 'leader-1',
        question: 'Is this leader effective?',
        status: 'ACTIVE',
        startTime: new Date('2026-01-01'),
        createdBy: new mongoose.Types.ObjectId(),
        likeCount: 10,
        dislikeCount: 2,
        totalVotes: 12,
        likeReasons: { helping_nature: 10 },
        dislikeReasons: { lack_responsiveness: 2 },
        reportsCount: 0,
        createdAt: new Date('2026-01-01'),
        updatedAt: new Date('2026-01-01'),
      } as any;

      const formatted = service.formatPollDto(legacyDoc);
      expect(formatted.people).toHaveLength(1);
      expect(formatted.people[0].name).toBe('Elderly Leader');
      expect(formatted.people[0].role).toBe('Social Worker');
      expect(formatted.questions).toHaveLength(1);
      expect(formatted.questions[0].text).toBe('Is this leader effective?');
      expect(formatted.questions[0].totalVotes).toBe(12);
      expect(formatted.questions[0].likePercentage).toBe(83.3);
    });

    test('reportPoll auto-flags poll as REPORTED when threshold (5 reports) is reached', async () => {
      mockRepo.findPollById.mockResolvedValue(samplePoll);
      mockRepo.findReport.mockResolvedValue(null);
      mockRepo.createReport.mockResolvedValue({
        report: { _id: new mongoose.Types.ObjectId() } as any,
        newReportsCount: 5,
      });

      await service.reportPoll(samplePoll._id.toString(), 'reporter-1', {
        reason: 'Misleading information',
        details: 'Biased framing',
      });

      expect(mockRepo.updatePollStatus).toHaveBeenCalledWith(samplePoll._id, 'REPORTED');
    });

    test('reportPoll prevents duplicate reports by the same user', async () => {
      mockRepo.findPollById.mockResolvedValue(samplePoll);
      mockRepo.findReport.mockResolvedValue({ _id: new mongoose.Types.ObjectId() } as any);

      await expect(
        service.reportPoll(samplePoll._id.toString(), 'reporter-1', {
          reason: 'Duplicate report',
        })
      ).rejects.toThrow(/already submitted a moderation report/);
    });
  });

  describe('Evaluated Person Profile Cards Data Model & DTOs', () => {
    test('createPoll stores and returns full profile card fields for each person', async () => {
      const creatorId = new mongoose.Types.ObjectId().toString();
      const p1Id = new mongoose.Types.ObjectId();
      const q1Id = new mongoose.Types.ObjectId();

      mockRepo.createPoll.mockImplementation(async (data: any) => {
        return {
          _id: new mongoose.Types.ObjectId(),
          ...data,
          createdAt: new Date(),
          updatedAt: new Date(),
        } as IPoll;
      });

      const res = await service.createPoll(creatorId, 'Poll Admin', {
        purpose: 'Electoral Candidates Verification',
        category: 'GOVERNANCE',
        people: [
          {
            name: 'Vikram Singh',
            role: 'Sarpanch',
            designation: 'Elected Gram Pradhan',
            officeContext: 'Current Term (2021-2026)',
            placeName: 'Khandela Village',
            photoUrl: 'https://example.com/vikram.jpg',
            workBackground: '12 years in agricultural cooperative management',
            publicServiceHistory: 'Built solar street lights and paved village drainage system',
            education: 'M.A. Political Science, Rajasthan University',
            achievements: 'Clean Village Governance Award 2023',
            casteCommunity: 'Rajput',
            religion: 'Hinduism',
            bio: 'Dedicated grassroots representative working on local water security',
            sourceReference: 'State Election Commission Affidavit 2021',
            verificationStatus: 'DOCUMENTED',
          },
        ],
        questions: [
          {
            text: 'Are you satisfied with Vikram Singh development work?',
          },
        ],
      });

      expect(res.people).toHaveLength(1);
      const person = res.people[0];
      expect(person.name).toBe('Vikram Singh');
      expect(person.role).toBe('Sarpanch');
      expect(person.designation).toBe('Elected Gram Pradhan');
      expect(person.officeContext).toBe('Current Term (2021-2026)');
      expect(person.placeName).toBe('Khandela Village');
      expect(person.photoUrl).toBe('https://example.com/vikram.jpg');
      expect(person.workBackground).toBe('12 years in agricultural cooperative management');
      expect(person.publicServiceHistory).toBe('Built solar street lights and paved village drainage system');
      expect(person.education).toBe('M.A. Political Science, Rajasthan University');
      expect(person.achievements).toBe('Clean Village Governance Award 2023');
      expect(person.casteCommunity).toBe('Rajput');
      expect(person.religion).toBe('Hinduism');
      expect(person.bio).toBe('Dedicated grassroots representative working on local water security');
      expect(person.sourceReference).toBe('State Election Commission Affidavit 2021');
      expect(person.verificationStatus).toBe('DOCUMENTED');
    });

    test('preserves privacy: caste/community and religion are optional and never inferred or populated by default', async () => {
      const creatorId = new mongoose.Types.ObjectId().toString();

      mockRepo.createPoll.mockImplementation(async (data: any) => {
        return {
          _id: new mongoose.Types.ObjectId(),
          ...data,
          createdAt: new Date(),
          updatedAt: new Date(),
        } as IPoll;
      });

      const res = await service.createPoll(creatorId, 'Citizen', {
        purpose: 'Impartial Candidate Review',
        people: [
          {
            name: 'Sunita Sharma',
            role: 'Ward Member',
            workBackground: 'Primary school educator',
            // Notice: casteCommunity, religion, sourceReference omitted
          },
        ],
        questions: [
          {
            text: 'How do you rate Sunita Sharma school advocacy?',
          },
        ],
      });

      expect(res.people).toHaveLength(1);
      const person = res.people[0];
      expect(person.name).toBe('Sunita Sharma');
      expect(person.casteCommunity).toBeNull();
      expect(person.religion).toBeNull();
      expect(person.sourceReference).toBeNull();
      expect(person.verificationStatus).toBe('UNVERIFIED');
    });

    test('rejects unauthorized non-staff user attempt to set verificationStatus to VERIFIED', async () => {
      const creatorId = new mongoose.Types.ObjectId().toString();

      await expect(
        service.createPoll(
          creatorId,
          'Ordinary Contributor',
          {
            people: [
              {
                name: 'Unauthorized Verified Candidate',
                verificationStatus: 'VERIFIED',
              },
            ],
            question: 'Valid question text here?',
          },
          USER_ROLES.CONTRIBUTOR
        )
      ).rejects.toThrow(AuthorizationError);
    });

    test('allows authorized staff to set VERIFIED status and allows ordinary user to set SELF_CLAIMED or DOCUMENTED', async () => {
      const creatorId = new mongoose.Types.ObjectId().toString();

      mockRepo.createPoll.mockImplementation(async (data: any) => {
        return {
          _id: new mongoose.Types.ObjectId(),
          ...data,
          createdAt: new Date(),
          updatedAt: new Date(),
        } as IPoll;
      });

      // Admin setting VERIFIED succeeds
      const adminRes = await service.createPoll(
        creatorId,
        'Admin Staff',
        {
          people: [
            {
              name: 'Officially Verified Official',
              verificationStatus: 'VERIFIED',
            },
          ],
          question: 'Valid question text here?',
        },
        USER_ROLES.ADMIN
      );
      expect(adminRes.people[0].verificationStatus).toBe('VERIFIED');

      // Ordinary contributor setting DOCUMENTED succeeds
      const contribRes = await service.createPoll(
        creatorId,
        'Citizen Contributor',
        {
          people: [
            {
              name: 'Documented Candidate',
              verificationStatus: 'DOCUMENTED',
              sourceReference: 'Election Commission Gazette 2024',
            },
          ],
          question: 'Valid question text here?',
        },
        USER_ROLES.CONTRIBUTOR
      );
      expect(contribRes.people[0].verificationStatus).toBe('DOCUMENTED');
    });

    test('supports administrative update of verificationStatus via moderatePoll with UPDATE_VERIFICATION', async () => {
      const pollId = new mongoose.Types.ObjectId();
      const personId = new mongoose.Types.ObjectId();

      const existingPoll: IPoll = {
        _id: pollId,
        personName: 'Candidate',
        question: 'Rate performance',
        status: 'ACTIVE',
        startTime: new Date(),
        createdBy: new mongoose.Types.ObjectId(),
        people: [
          {
            _id: personId,
            name: 'Candidate',
            verificationStatus: 'UNVERIFIED',
          } as any,
        ],
        questions: [],
        likeCount: 0,
        dislikeCount: 0,
        totalVotes: 0,
        likeReasons: {},
        dislikeReasons: {},
        reportsCount: 0,
        createdAt: new Date(),
        updatedAt: new Date(),
      } as any;

      mockRepo.findPollById.mockResolvedValue(existingPoll);
      mockRepo.updatePersonVerificationStatus = jest.fn().mockResolvedValue({
        ...existingPoll,
        people: [
          {
            _id: personId,
            name: 'Candidate',
            verificationStatus: 'VERIFIED',
          },
        ],
      } as any);

      const modRes = await service.moderatePoll(pollId.toString(), USER_ROLES.ADMIN, {
        action: 'UPDATE_VERIFICATION',
        personId: personId.toString(),
        verificationStatus: 'VERIFIED',
      });

      expect(modRes.people[0].verificationStatus).toBe('VERIFIED');
      expect(mockRepo.updatePersonVerificationStatus).toHaveBeenCalledWith(
        pollId,
        personId.toString(),
        'VERIFIED'
      );
    });
  });
});
