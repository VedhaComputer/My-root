import mongoose, { FilterQuery, ClientSession } from 'mongoose';
import { ClaimModel, IClaim, ILocalizedContent } from './claim.model';
import { ClaimCategory, ClaimStatus } from '../../shared/constants';
import { AppError } from '../../shared/errors/AppError';

export interface CreateClaimRepoData {
  title: ILocalizedContent;
  body: ILocalizedContent;
  category: ClaimCategory;
  status: ClaimStatus;
  locationId: mongoose.Types.ObjectId | string;
  locationPath: (mongoose.Types.ObjectId | string)[];
  submittedBy: mongoose.Types.ObjectId;
  tags?: string[];
  isPublic?: boolean;
  communityTopic?: string;
  sourceAttribution?: string;
  timePeriod?: string;
  consentObtained?: boolean;
  consentDetails?: string;
  consentState?: 'not_applicable' | 'pending_verification' | 'consent_verified' | 'consent_revoked';
  userAgreementStatus?: 'agreed' | 'correction' | 'different_account' | 'dont_know';
}

export interface ListClaimsFilter {
  status?: ClaimStatus;
  category?: ClaimCategory;
  locationId?: string;
  communityTopic?: string;
  submittedBy?: string;
  publicOnly?: boolean;
}

export interface PaginationOptions {
  page: number;
  limit: number;
}

export class ClaimRepository {
  /**
   * Evaluates deployment topology upfront to determine whether multi-document ACID
   * transactions are supported (Replica Set or Sharded Cluster).
   * Standalone MongoDB deployments ('Single' topology) cannot provide multi-document
   * ACID guarantees, but execute operations individually without replay risk.
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
      // When connected via directConnection=true to a replica set member,
      // driver topology type is 'Single', but the server itself is 'RSPrimary', supporting transactions.
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
   * Executes a unit of work inside a managed MongoDB transaction with session propagation
   * when supported by the deployment topology (replica set member or mongos).
   *
   * PRODUCTION FAIL-CLOSED POLICY:
   * Production must fail closed if the required replica-set/sharded transaction capability is unavailable.
   * Standalone development is supported only in non-production environments with an explicit warning,
   * executing work directly once without starting a transaction session (eliminating any replay risk).
   */
  async withTransaction<T>(work: (session: ClientSession) => Promise<T>): Promise<T> {
    const isProduction = process.env.NODE_ENV === 'production';
    const hasTransactions = this.supportsTransactions();

    if (!hasTransactions) {
      if (isProduction) {
        throw new AppError(
          'Production requires a replica-set or sharded MongoDB deployment for multi-document ACID transactions. Non-transactional execution is prohibited in production.',
          500,
          'TRANSACTIONS_NOT_SUPPORTED',
          true
        );
      }
      // Non-production standalone development fallback:
      // Execute the unit of work directly once without starting a transaction session.
      // This eliminates any catch-and-replay risk or duplicate audit/claim writes.
      return await work(undefined as any as ClientSession);
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
    } catch (error: any) {
      if (
        error?.code === 20 ||
        error?.codeName === 'IllegalOperation' ||
        (typeof error?.message === 'string' &&
          error.message.includes('Transaction numbers are only allowed on a replica set member or mongos'))
      ) {
        throw new AppError(
          'MongoDB multi-document transactions are not supported by the current deployment. A replica set is required.',
          500,
          'TRANSACTIONS_NOT_SUPPORTED',
          true
        );
      }
      throw error;
    } finally {
      await session.endSession();
    }
  }

  /**
   * Atomically acquires an exclusive write lock on the document in WiredTiger
   * by incrementing __v within a transaction session.
   */
  async touch(id: string, session?: ClientSession): Promise<IClaim | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return null;
    }
    const query = ClaimModel.findByIdAndUpdate(
      id,
      { $inc: { __v: 1 } },
      { new: true }
    );
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async create(data: CreateClaimRepoData, session?: ClientSession): Promise<IClaim> {
    const claim = new ClaimModel({
      title: data.title,
      body: data.body,
      category: data.category,
      status: data.status,
      locationId: data.locationId,
      locationPath: data.locationPath,
      submittedBy: data.submittedBy,
      tags: data.tags ?? [],
      isPublic: data.isPublic ?? true,
      communityTopic: data.communityTopic ?? null,
      sourceAttribution: data.sourceAttribution ?? null,
      timePeriod: data.timePeriod ?? null,
      consentObtained: data.consentObtained ?? false,
      consentDetails: data.consentDetails ?? null,
      consentState: data.consentState ?? (data.communityTopic === 'biography' ? 'pending_verification' : 'not_applicable'),
      userAgreementStatus: data.userAgreementStatus ?? null,
      submittedAt: new Date(),
      updatedAt: new Date(),
    });

    return await claim.save({ session });
  }

  async findById(id: string, session?: ClientSession): Promise<IClaim | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return null;
    }
    const query = ClaimModel.findById(id);
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async update(
    id: string,
    updateFields: Record<string, any>,
    session?: ClientSession
  ): Promise<IClaim | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return null;
    }

    const updateDoc: any = {};
    const setFields: Record<string, any> = { updatedAt: new Date() };

    for (const [key, value] of Object.entries(updateFields)) {
      if (key.startsWith('$')) {
        updateDoc[key] = value;
      } else {
        setFields[key] = value;
      }
    }
    updateDoc.$set = setFields;

    const query = ClaimModel.findByIdAndUpdate(
      id,
      updateDoc,
      { new: true, runValidators: true }
    );
    if (session) {
      query.session(session);
    }
    return await query.exec();
  }

  async list(
    filter: ListClaimsFilter,
    pagination: PaginationOptions,
    session?: ClientSession
  ): Promise<{ claims: IClaim[]; total: number }> {
    const query: FilterQuery<IClaim> = {};

    if (filter.status) {
      query.status = filter.status;
    }

    if (filter.category) {
      query.category = filter.category;
    }

    if (filter.communityTopic) {
      query.communityTopic = filter.communityTopic;
    }

    if (filter.submittedBy && mongoose.Types.ObjectId.isValid(filter.submittedBy)) {
      query.submittedBy = new mongoose.Types.ObjectId(filter.submittedBy);
    }

    if (filter.locationId) {
      query.locationId = mongoose.Types.ObjectId.isValid(filter.locationId)
        ? new mongoose.Types.ObjectId(filter.locationId)
        : filter.locationId;
    }

    if (filter.publicOnly) {
      query.isPublic = true;
      if (!filter.status) {
        query.status = { $ne: 'draft' as any };
      }
      // Living person biographies require actual verified consent before public publication
      query.$nor = [
        { communityTopic: 'biography', consentState: { $ne: 'consent_verified' } },
        { category: 'PERSONAL_EXPERIENCE', consentState: { $in: ['pending_verification', 'consent_revoked'] } },
      ];
    }

    const skip = (pagination.page - 1) * pagination.limit;

    const findQuery = ClaimModel.find(query)
      .sort({ submittedAt: -1 })
      .skip(skip)
      .limit(pagination.limit);
    const countQuery = ClaimModel.countDocuments(query);

    if (session) {
      findQuery.session(session);
      countQuery.session(session);
    }

    const [claims, total] = await Promise.all([
      findQuery.exec(),
      countQuery.exec(),
    ]);

    return { claims, total };
  }
}

export const claimRepository = new ClaimRepository();
