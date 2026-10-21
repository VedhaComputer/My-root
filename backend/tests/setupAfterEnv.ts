import mongoose from 'mongoose';
import { UserModel } from '../src/modules/auth/user.model';
import { reviewRepository } from '../src/modules/verification/repository';
import { auditService } from '../src/modules/audit/audit.service';

// For route integration tests (claims, places, evidence) that use synthetic tokens,
// provide default mocks so they don't require database fixtures.
// Dedicated authentication and security tests can override these spies with their own mocks or live queries.
beforeEach(() => {
  if ((mongoose.connection as any).readyState === 0) {
    (mongoose.connection as any).readyState = 1;
  }

  if (!jest.isMockFunction(UserModel.findById)) {
    jest.spyOn(UserModel, 'findById').mockImplementation((id: any) => ({
      select: () => ({
        lean: () => ({
          exec: async () => ({
            _id: mongoose.Types.ObjectId.isValid(id) ? new mongoose.Types.ObjectId(id) : id,
            isActive: true,
            tokenVersion: 1,
          }),
        }),
      }),
    } as any));
  }

  if (!jest.isMockFunction(reviewRepository.findLatestByClaimId)) {
    jest.spyOn(reviewRepository, 'findLatestByClaimId').mockResolvedValue(null);
  }

  if (!jest.isMockFunction(auditService.writeAuditLog)) {
    jest.spyOn(auditService, 'writeAuditLog').mockResolvedValue({} as any);
  }
});
