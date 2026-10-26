import mongoose from 'mongoose';
import { PollService } from '../../../../src/modules/polls/service';
import { PollRepository } from '../../../../src/modules/polls/repository';
import { IPoll } from '../../../../src/modules/polls/poll.model';
import { USER_ROLES } from '../../../../src/shared/constants';
import { ValidationError, AuthorizationError } from '../../../../src/shared/errors/AppError';

describe('PollService (Unit Tests)', () => {
  let mockRepo: jest.Mocked<PollRepository>;
  let service: PollService;

  beforeEach(() => {
    mockRepo = {
      createPoll: jest.fn(),
      findPollById: jest.fn(),
      findPolls: jest.fn(),
      findUserVote: jest.fn(),
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
      service.castVote('poll-1', 'user-1', {
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
});
