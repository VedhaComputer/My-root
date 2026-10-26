import request from 'supertest';
import jwt from 'jsonwebtoken';
import mongoose from 'mongoose';
import { createApp } from '../../src/app';
import { env } from '../../src/config/env';
import { USER_ROLES, UserRole } from '../../src/shared/constants';
import { PollModel, PollVoteModel, PollReportModel } from '../../src/modules/polls/poll.model';

const app = createApp();

function generateTestToken(role: UserRole = USER_ROLES.CONTRIBUTOR, userId = new mongoose.Types.ObjectId().toString()): string {
  return jwt.sign(
    {
      userId,
      email: 'polluser@example.com',
      role,
      displayName: 'Poll Voter',
      tokenVersion: 1,
    },
    env.JWT_ACCESS_SECRET,
    {
      algorithm: 'HS256',
      issuer: env.JWT_ISSUER,
      audience: env.JWT_AUDIENCE,
      expiresIn: '15m',
    }
  );
}

describe('Polls Routes (Integration Tests)', () => {
  let originalFallback: string | undefined;

  beforeAll(async () => {
    originalFallback = process.env.JWT_ALLOW_HS256_FALLBACK;
    process.env.JWT_ALLOW_HS256_FALLBACK = 'true';

    if (mongoose.connection.readyState !== 1) {
      const TEST_PORT = 27018;
      const TEST_DB = 'myroot_polls_test';
      const TEST_URI = `mongodb://127.0.0.1:${TEST_PORT}/${TEST_DB}?directConnection=true`;
      try {
        await mongoose.connect(TEST_URI, {
          serverSelectionTimeoutMS: 3000,
        });
      } catch {
        // Fall back to standard port 27017
        try {
          await mongoose.connect('mongodb://127.0.0.1:27017/myroot_polls_test', {
            serverSelectionTimeoutMS: 3000,
          });
        } catch (_) {}
      }
    }
  });

  afterAll(async () => {
    if (originalFallback === undefined) {
      delete process.env.JWT_ALLOW_HS256_FALLBACK;
    } else {
      process.env.JWT_ALLOW_HS256_FALLBACK = originalFallback;
    }
    if (mongoose.connection.readyState === 1) {
      await mongoose.disconnect();
    }
  });

  afterEach(async () => {
    await PollModel.deleteMany({});
    await PollVoteModel.deleteMany({});
    await PollReportModel.deleteMany({});
  });

  it('rejects unauthenticated requests to poll endpoints with 401', async () => {
    const resGet = await request(app).get('/api/v1/polls');
    expect(resGet.status).toBe(401);

    const resPost = await request(app).post('/api/v1/polls').send({ personName: 'Test' });
    expect(resPost.status).toBe(401);
  });

  it('creates a poll with valid fields and defaults', async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const token = generateTestToken(USER_ROLES.CONTRIBUTOR, userId);

    const res = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${token}`)
      .send({
        personName: 'Shri Ram Sharma',
        personRole: 'Sarpanch',
        placeName: 'Amer Village',
        placeId: 'PL_VIL_amer',
        targetEntityId: 'sarpanch',
        question: 'What is your opinion on the work and conduct of Sarpanch Shri Ram Sharma?',
        description: 'Public opinion survey on village development activities and governance.',
        durationDays: 30,
      });

    expect(res.status).toBe(201);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.personName).toBe('Shri Ram Sharma');
    expect(res.body.data.personRole).toBe('Sarpanch');
    expect(res.body.data.status).toBe('ACTIVE');
    expect(res.body.data.totalVotes).toBe(0);
    expect(res.body.data.likeCount).toBe(0);
    expect(res.body.data.dislikeCount).toBe(0);
    expect(res.body.data.likePercentage).toBe(0);
    expect(res.body.data.dislikePercentage).toBe(0);
    expect(res.body.data.endTime).toBeDefined();
  });

  it('rejects poll creation with invalid or missing required fields', async () => {
    const token = generateTestToken();

    const res = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${token}`)
      .send({
        personName: 'R', // too short
        question: 'Hi',  // too short
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('lists and searches polls', async () => {
    const token = generateTestToken();

    // Create two polls
    await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${token}`)
      .send({
        personName: 'Dr. APJ Abdul Kalam',
        personRole: 'Former President',
        question: 'How do you view Dr. Kalam’s scientific and educational legacy?',
      });

    await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${token}`)
      .send({
        personName: 'Sita Devi',
        personRole: 'Ward Member',
        question: 'What is your opinion on Ward Member Sita Devi’s responsiveness?',
      });

    const listRes = await request(app)
      .get('/api/v1/polls')
      .set('Authorization', `Bearer ${token}`);

    expect(listRes.status).toBe(200);
    expect(listRes.body.data.length).toBe(2);
    expect(listRes.body.pagination.total).toBe(2);

    // Search by personName
    const searchRes = await request(app)
      .get('/api/v1/polls?search=Kalam')
      .set('Authorization', `Bearer ${token}`);

    expect(searchRes.status).toBe(200);
    expect(searchRes.body.data.length).toBe(1);
    expect(searchRes.body.data[0].personName).toBe('Dr. APJ Abdul Kalam');
  });

  it('supports casting a vote, atomically updating totals and reason breakdowns', async () => {
    const user1Id = new mongoose.Types.ObjectId().toString();
    const token1 = generateTestToken(USER_ROLES.CONTRIBUTOR, user1Id);

    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${token1}`)
      .send({
        personName: 'Vikram Singh',
        personRole: 'MLA',
        question: 'What is your opinion on Vikram Singh MLA?',
      });

    const pollId = createRes.body.data.id;

    // User 1 casts LIKE with reason 'work_performance'
    const voteRes1 = await request(app)
      .post(`/api/v1/polls/${pollId}/vote`)
      .set('Authorization', `Bearer ${token1}`)
      .send({
        choice: 'LIKE',
        reasonKey: 'work_performance',
        explanation: 'Built village road on time',
      });

    expect(voteRes1.status).toBe(200);
    expect(voteRes1.body.data.totalVotes).toBe(1);
    expect(voteRes1.body.data.likeCount).toBe(1);
    expect(voteRes1.body.data.dislikeCount).toBe(0);
    expect(voteRes1.body.data.likePercentage).toBe(100);
    expect(voteRes1.body.data.dislikePercentage).toBe(0);
    expect(voteRes1.body.data.userVote).toBeDefined();
    expect(voteRes1.body.data.userVote.choice).toBe('LIKE');
    expect(voteRes1.body.data.userVote.reasonKey).toBe('work_performance');
    expect(voteRes1.body.data.likeReasons.length).toBe(1);
    expect(voteRes1.body.data.likeReasons[0].key).toBe('work_performance');
    expect(voteRes1.body.data.likeReasons[0].count).toBe(1);
    expect(voteRes1.body.data.likeReasons[0].percentage).toBe(100);

    // User 2 casts DISLIKE with reason 'promises_unfulfilled'
    const user2Id = new mongoose.Types.ObjectId().toString();
    const token2 = generateTestToken(USER_ROLES.CONTRIBUTOR, user2Id);

    const voteRes2 = await request(app)
      .post(`/api/v1/polls/${pollId}/vote`)
      .set('Authorization', `Bearer ${token2}`)
      .send({
        choice: 'DISLIKE',
        reasonKey: 'promises_unfulfilled',
        explanation: 'Did not attend ward meetings',
      });

    expect(voteRes2.status).toBe(200);
    expect(voteRes2.body.data.totalVotes).toBe(2);
    expect(voteRes2.body.data.likeCount).toBe(1);
    expect(voteRes2.body.data.dislikeCount).toBe(1);
    expect(voteRes2.body.data.likePercentage).toBe(50);
    expect(voteRes2.body.data.dislikePercentage).toBe(50);
    expect(voteRes2.body.data.dislikeReasons.length).toBe(1);
    expect(voteRes2.body.data.dislikeReasons[0].key).toBe('promises_unfulfilled');
    expect(voteRes2.body.data.dislikeReasons[0].count).toBe(1);

    // User 1 changes their vote from LIKE to DISLIKE with reason 'behaviour_concerns'
    const voteChangeRes = await request(app)
      .post(`/api/v1/polls/${pollId}/vote`)
      .set('Authorization', `Bearer ${token1}`)
      .send({
        choice: 'DISLIKE',
        reasonKey: 'behaviour_concerns',
        explanation: 'Changed my mind due to recent statements',
      });

    expect(voteChangeRes.status).toBe(200);
    expect(voteChangeRes.body.data.totalVotes).toBe(2); // Still 2 votes, not 3!
    expect(voteChangeRes.body.data.likeCount).toBe(0);
    expect(voteChangeRes.body.data.dislikeCount).toBe(2);
    expect(voteChangeRes.body.data.likePercentage).toBe(0);
    expect(voteChangeRes.body.data.dislikePercentage).toBe(100);
    expect(voteChangeRes.body.data.userVote.choice).toBe('DISLIKE');
    expect(voteChangeRes.body.data.userVote.reasonKey).toBe('behaviour_concerns');

    // Verify likeReasons has 0 active counts, dislikeReasons has 2
    const totalDislikeReasonsCount = voteChangeRes.body.data.dislikeReasons.reduce(
      (sum: number, r: any) => sum + r.count,
      0
    );
    expect(totalDislikeReasonsCount).toBe(2);
  });

  it('rejects votes when poll is closed', async () => {
    const creatorId = new mongoose.Types.ObjectId().toString();
    const token = generateTestToken(USER_ROLES.CONTRIBUTOR, creatorId);

    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${token}`)
      .send({
        personName: 'Rajesh Kumar',
        question: 'Opinion on Rajesh Kumar?',
      });

    const pollId = createRes.body.data.id;

    // Creator closes poll
    const closeRes = await request(app)
      .post(`/api/v1/polls/${pollId}/close`)
      .set('Authorization', `Bearer ${token}`);

    expect(closeRes.status).toBe(200);
    expect(closeRes.body.data.status).toBe('CLOSED');

    // Attempt to vote on closed poll
    const voteRes = await request(app)
      .post(`/api/v1/polls/${pollId}/vote`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        choice: 'LIKE',
        reasonKey: 'work_performance',
      });

    expect(voteRes.status).toBe(400);
    expect(voteRes.body.error.message).toMatch(/closed/i);
  });

  it('allows reporting an inappropriate or abusive poll', async () => {
    const token = generateTestToken();

    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${token}`)
      .send({
        personName: 'Public Figure',
        question: 'Neutral question for public figure?',
      });

    const pollId = createRes.body.data.id;

    const reportRes = await request(app)
      .post(`/api/v1/polls/${pollId}/report`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        reason: 'defamation',
        details: 'Contains misleading allegations in title',
      });

    expect(reportRes.status).toBe(200);
    expect(reportRes.body.data.reportId).toBeDefined();

    // Verify poll report count incremented
    const pollRes = await request(app)
      .get(`/api/v1/polls/${pollId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(pollRes.body.data.reportsCount).toBe(1);

    // Duplicate report from the same user is rejected
    const dupReportRes = await request(app)
      .post(`/api/v1/polls/${pollId}/report`)
      .set('Authorization', `Bearer ${token}`)
      .send({
        reason: 'defamation',
      });
    expect(dupReportRes.status).toBe(400);
    expect(dupReportRes.body.error.message).toMatch(/already submitted/i);
  });

  it('preserves counter and vote integrity under concurrent duplicate vote submissions (concurrency regression)', async () => {
    const creatorToken = generateTestToken();
    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${creatorToken}`)
      .send({
        personName: 'Concurrent Candidate',
        question: 'Opinion on Concurrent Candidate?',
      });

    const pollId = createRes.body.data.id;
    const voterId = new mongoose.Types.ObjectId().toString();
    const voterToken = generateTestToken(USER_ROLES.CONTRIBUTOR, voterId);

    // Fire 5 concurrent identical vote submissions from the exact same user
    const concurrentRequests = Array.from({ length: 5 }, () =>
      request(app)
        .post(`/api/v1/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({
          choice: 'LIKE',
          reasonKey: 'work_performance',
          explanation: 'Concurrent test vote',
        })
    );

    const results = await Promise.all(concurrentRequests);

    // All successful responses (200)
    for (const res of results) {
      expect([200]).toContain(res.status);
    }

    // Verify database state: exactly ONE vote record exists
    const votesInDb = await PollVoteModel.find({ pollId, userId: voterId });
    expect(votesInDb.length).toBe(1);

    // Verify poll aggregate totals: totalVotes is 1, likeCount is 1
    const pollDoc = await PollModel.findById(pollId);
    expect(pollDoc!.totalVotes).toBe(1);
    expect(pollDoc!.likeCount).toBe(1);
    expect(pollDoc!.dislikeCount).toBe(0);
    const reasonCount =
      typeof (pollDoc!.likeReasons as any)?.get === 'function'
        ? (pollDoc!.likeReasons as any).get('work_performance')
        : (pollDoc!.likeReasons as any)['work_performance'];
    expect(reasonCount).toBe(1);
  });

  it('preserves counter integrity under concurrent vote switching (concurrency regression)', async () => {
    const creatorToken = generateTestToken();
    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${creatorToken}`)
      .send({
        personName: 'Switch Candidate',
        question: 'Opinion on Switch Candidate?',
      });

    const pollId = createRes.body.data.id;
    const voterId = new mongoose.Types.ObjectId().toString();
    const voterToken = generateTestToken(USER_ROLES.CONTRIBUTOR, voterId);

    // First vote: initial LIKE
    const initialVote = await request(app)
      .post(`/api/v1/polls/${pollId}/vote`)
      .set('Authorization', `Bearer ${voterToken}`)
      .send({
        choice: 'LIKE',
        reasonKey: 'work_performance',
      });
    expect(initialVote.status).toBe(200);

    // Fire 6 concurrent requests with alternating LIKE/DISLIKE choices
    const switchRequests = [
      request(app)
        .post(`/api/v1/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({ choice: 'DISLIKE', reasonKey: 'lack_responsiveness' }),
      request(app)
        .post(`/api/v1/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({ choice: 'LIKE', reasonKey: 'public_service' }),
      request(app)
        .post(`/api/v1/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({ choice: 'DISLIKE', reasonKey: 'promises_unfulfilled' }),
      request(app)
        .post(`/api/v1/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({ choice: 'LIKE', reasonKey: 'work_performance' }),
      request(app)
        .post(`/api/v1/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({ choice: 'DISLIKE', reasonKey: 'lack_responsiveness' }),
      request(app)
        .post(`/api/v1/polls/${pollId}/vote`)
        .set('Authorization', `Bearer ${voterToken}`)
        .send({ choice: 'DISLIKE', reasonKey: 'lack_responsiveness' }),
    ];

    const results = await Promise.all(switchRequests);
    for (const res of results) {
      expect([200]).toContain(res.status);
    }

    // Verify vote record count is still 1
    const votesInDb = await PollVoteModel.find({ pollId, userId: voterId });
    expect(votesInDb.length).toBe(1);
    const finalVote = votesInDb[0];

    // Verify poll aggregate totals are strictly consistent with the final vote
    const pollDoc = await PollModel.findById(pollId);
    expect(pollDoc!.totalVotes).toBe(1);

    if (finalVote.choice === 'LIKE') {
      expect(pollDoc!.likeCount).toBe(1);
      expect(pollDoc!.dislikeCount).toBe(0);
    } else {
      expect(pollDoc!.likeCount).toBe(0);
      expect(pollDoc!.dislikeCount).toBe(1);
    }
  });

  it('rejects moderation attempts by non-staff users with 403 Forbidden', async () => {
    const creatorToken = generateTestToken();
    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${creatorToken}`)
      .send({
        personName: 'Test Target',
        question: 'Question text?',
      });

    const pollId = createRes.body.data.id;
    const contributorToken = generateTestToken(USER_ROLES.CONTRIBUTOR);

    const res = await request(app)
      .post(`/api/v1/polls/${pollId}/moderate`)
      .set('Authorization', `Bearer ${contributorToken}`)
      .send({ action: 'REMOVE' });

    expect(res.status).toBe(403);
    expect(res.body.error.message).toMatch(/Requires MODERATOR role/i);
  });

  it('verifies distinct persisted effects for REMOVE, CLOSE, and DISMISS_REPORTS by moderators', async () => {
    const creatorToken = generateTestToken();
    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${creatorToken}`)
      .send({
        personName: 'Moderated Person',
        question: 'Initial active question?',
      });

    const pollId = createRes.body.data.id;
    const modToken = generateTestToken(USER_ROLES.MODERATOR);

    // 1. CLOSE action: sets status to CLOSED and sets endTime
    const closeRes = await request(app)
      .post(`/api/v1/polls/${pollId}/moderate`)
      .set('Authorization', `Bearer ${modToken}`)
      .send({ action: 'CLOSE' });

    expect(closeRes.status).toBe(200);
    expect(closeRes.body.data.status).toBe('CLOSED');
    const closedDoc = await PollModel.findById(pollId);
    expect(closedDoc!.status).toBe('CLOSED');
    expect(closedDoc!.endTime).toBeDefined();

    // 2. DISMISS_REPORTS action: clears reportsCount and resets status to ACTIVE
    await PollReportModel.create({
      pollId: new mongoose.Types.ObjectId(pollId),
      reportedBy: new mongoose.Types.ObjectId(),
      reason: 'spam',
      status: 'PENDING',
    });
    await PollModel.findByIdAndUpdate(pollId, { $set: { reportsCount: 3, status: 'REPORTED' } });

    const dismissRes = await request(app)
      .post(`/api/v1/polls/${pollId}/moderate`)
      .set('Authorization', `Bearer ${modToken}`)
      .send({ action: 'DISMISS_REPORTS' });

    expect(dismissRes.status).toBe(200);
    expect(dismissRes.body.data.status).toBe('ACTIVE');
    expect(dismissRes.body.data.reportsCount).toBe(0);
    const dismissedDoc = await PollModel.findById(pollId);
    expect(dismissedDoc!.reportsCount).toBe(0);
    expect(dismissedDoc!.status).toBe('ACTIVE');

    // 3. REMOVE action: sets status to REMOVED
    const removeRes = await request(app)
      .post(`/api/v1/polls/${pollId}/moderate`)
      .set('Authorization', `Bearer ${modToken}`)
      .send({ action: 'REMOVE' });

    expect(removeRes.status).toBe(200);
    expect(removeRes.body.data.status).toBe('REMOVED');
    const removedDoc = await PollModel.findById(pollId);
    expect(removedDoc!.status).toBe('REMOVED');
  });

  it('auto-transitions status to REPORTED when concurrent reports from distinct users reach threshold 5', async () => {
    const creatorToken = generateTestToken();
    const createRes = await request(app)
      .post('/api/v1/polls')
      .set('Authorization', `Bearer ${creatorToken}`)
      .send({
        personName: 'Threshold Person',
        question: 'Under review question?',
      });

    const pollId = createRes.body.data.id;

    // Fire 5 reports from 5 distinct users concurrently
    const reportPromises = Array.from({ length: 5 }, () => {
      const distinctUserToken = generateTestToken(USER_ROLES.CONTRIBUTOR);
      return request(app)
        .post(`/api/v1/polls/${pollId}/report`)
        .set('Authorization', `Bearer ${distinctUserToken}`)
        .send({ reason: 'defamation', details: 'Automated test report' });
    });

    const reportResults = await Promise.all(reportPromises);
    for (const r of reportResults) {
      expect(r.status).toBe(200);
    }

    const pollDoc = await PollModel.findById(pollId);
    expect(pollDoc!.reportsCount).toBe(5);
    expect(pollDoc!.status).toBe('REPORTED');
  });
});
