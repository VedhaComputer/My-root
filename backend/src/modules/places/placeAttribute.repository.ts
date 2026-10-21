import mongoose from 'mongoose';
import { PlaceAttributeModel, IPlaceAttribute, IPlaceAttributeHistory } from './placeAttribute.model';
import { NotFoundError, AuthorizationError, SelfReviewError } from '../../shared/errors/AppError';
import { USER_ROLES, UserRole, hasMinimumRole } from '../../shared/constants';
import { AuthenticatedUser } from '../../shared/types';
import { auditService } from '../audit/audit.service';

export interface CreatePlaceAttributeInput {
  placeId: string;
  category: 'population' | 'leadership' | 'facility' | 'development' | 'issue' | 'identity';
  key: string;
  value: string;
  sourceDescription: string;
  reportedPeriod?: string | null;
  reportedDate?: string | null;
  uncertainty?: string | null;
}

export interface CorrectPlaceAttributeInput {
  value: string;
  sourceDescription: string;
  reportedPeriod?: string | null;
  reportedDate?: string | null;
  uncertainty?: string | null;
  correctionReason?: string | null;
}

export class PlaceAttributeRepository {
  async create(
    data: CreatePlaceAttributeInput & { submittedBy: string; userRole?: UserRole }
  ): Promise<IPlaceAttribute> {
    const isPrivileged = data.userRole && hasMinimumRole(data.userRole, USER_ROLES.REVIEWER);
    const initialStatus = isPrivileged ? 'verified' : 'pending_review';

    const attr = new PlaceAttributeModel({
      placeId: new mongoose.Types.ObjectId(data.placeId),
      category: data.category,
      key: data.key.trim(),
      value: data.value.trim(),
      sourceDescription: data.sourceDescription.trim(),
      reportedPeriod: data.reportedPeriod ? data.reportedPeriod.trim() : null,
      reportedDate: data.reportedDate ? new Date(data.reportedDate) : null,
      uncertainty: data.uncertainty ? data.uncertainty.trim() : null,
      submittedBy: new mongoose.Types.ObjectId(data.submittedBy),
      status: initialStatus,
      reviewedBy: isPrivileged ? new mongoose.Types.ObjectId(data.submittedBy) : null,
      reviewedAt: isPrivileged ? new Date() : null,
      history: [],
      isLatest: true,
    });

    return await attr.save();
  }

  async findById(id: string): Promise<IPlaceAttribute | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) return null;
    return await PlaceAttributeModel.findById(id).exec();
  }

  async findByPlaceId(
    placeId: string,
    category?: string,
    callerUser?: AuthenticatedUser | null
  ): Promise<IPlaceAttribute[]> {
    if (!mongoose.Types.ObjectId.isValid(placeId)) return [];
    const query: Record<string, any> = { placeId: new mongoose.Types.ObjectId(placeId) };

    if (category && typeof category === 'string' && /^[a-zA-Z0-9_-]+$/.test(category)) {
      query.category = category;
    }

    const isPrivileged = callerUser?.role && hasMinimumRole(callerUser.role, USER_ROLES.REVIEWER);
    if (!isPrivileged) {
      if (callerUser?.userId && mongoose.Types.ObjectId.isValid(callerUser.userId)) {
        query.$or = [
          { status: 'verified' },
          { submittedBy: new mongoose.Types.ObjectId(callerUser.userId) },
        ];
      } else {
        query.status = 'verified';
      }
    }

    return await PlaceAttributeModel.find(query).sort({ createdAt: -1 }).exec();
  }

  async reviewAttribute(
    attrId: string,
    decision: 'verified' | 'rejected',
    reviewerId: string,
    reviewerRole: UserRole,
    reviewNotes?: string | null
  ): Promise<IPlaceAttribute> {
    if (!hasMinimumRole(reviewerRole, USER_ROLES.REVIEWER)) {
      throw new AuthorizationError('Requires REVIEWER role or higher to review place attributes');
    }
    const attr = await this.findById(attrId);
    if (!attr) {
      throw new NotFoundError('PlaceAttribute');
    }

    if (attr.submittedBy.toString() === reviewerId) {
      throw new SelfReviewError();
    }

    attr.status = decision;
    attr.reviewedBy = new mongoose.Types.ObjectId(reviewerId);
    attr.reviewedAt = new Date();
    attr.reviewNotes = reviewNotes ? reviewNotes.trim() : null;

    return await attr.save();
  }

  async getAttributeHistory(attrId: string): Promise<IPlaceAttributeHistory[]> {
    const attr = await this.findById(attrId);
    if (!attr) {
      throw new NotFoundError('PlaceAttribute');
    }
    return attr.history || [];
  }

  async correctAttribute(
    id: string,
    data: CorrectPlaceAttributeInput,
    userId: string,
    userRole?: UserRole,
    ip?: string
  ): Promise<IPlaceAttribute> {
    const attr = await this.findById(id);
    if (!attr) {
      throw new NotFoundError('PlaceAttribute');
    }

    const isOwner = Boolean(attr.submittedBy && attr.submittedBy.toString() === userId);
    const isReviewerOrHigher = Boolean(userRole && hasMinimumRole(userRole, USER_ROLES.REVIEWER));

    if (!isOwner && !isReviewerOrHigher) {
      throw new AuthorizationError('Only the original contributor or a reviewer/admin can modify this attribute');
    }

    const previousSnapshot = {
      value: attr.value,
      sourceDescription: attr.sourceDescription,
      reportedPeriod: attr.reportedPeriod,
      reportedDate: attr.reportedDate,
      uncertainty: attr.uncertainty,
    };

    const historyEntry: IPlaceAttributeHistory = {
      value: attr.value,
      sourceDescription: attr.sourceDescription,
      reportedPeriod: attr.reportedPeriod,
      reportedDate: attr.reportedDate,
      uncertainty: attr.uncertainty,
      correctedBy: new mongoose.Types.ObjectId(userId),
      correctedAt: new Date(),
      correctionReason: data.correctionReason ? data.correctionReason.trim() : null,
    };

    if (!attr.history) {
      attr.history = [];
    }
    attr.history.push(historyEntry);

    attr.value = data.value.trim();
    attr.sourceDescription = data.sourceDescription.trim();
    if (data.reportedPeriod !== undefined) {
      attr.reportedPeriod = data.reportedPeriod ? data.reportedPeriod.trim() : null;
    }
    if (data.reportedDate !== undefined) {
      attr.reportedDate = data.reportedDate ? new Date(data.reportedDate) : null;
    }
    if (data.uncertainty !== undefined) {
      attr.uncertainty = data.uncertainty ? data.uncertainty.trim() : null;
    }

    const saved = await attr.save();

    await auditService.writeAuditLog({
      entityType: 'place',
      entityId: attr.placeId,
      actorId: userId,
      action: 'place_attribute.corrected',
      before: previousSnapshot,
      after: {
        value: saved.value,
        sourceDescription: saved.sourceDescription,
        reportedPeriod: saved.reportedPeriod,
        reportedDate: saved.reportedDate,
        uncertainty: saved.uncertainty,
        correctionReason: historyEntry.correctionReason,
      },
      ipAddress: ip,
      metadata: {
        attributeId: saved._id.toString(),
        category: saved.category,
        key: saved.key,
      },
    });

    return saved;
  }
}

export const placeAttributeRepository = new PlaceAttributeRepository();

