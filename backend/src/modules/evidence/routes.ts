import { Router } from 'express';
import { evidenceController } from './controller';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { validateBody, validateParams } from '../../middleware/validateRequest';
import {
  createEvidenceSchema,
  reviewEvidenceSchema,
  evidenceIdParamSchema,
  evidenceClaimIdParamSchema,
} from './validation';
import { USER_ROLES } from '../../shared/constants';

const router = Router();

router.get('/claim/:claimId', authenticate, validateParams(evidenceClaimIdParamSchema), evidenceController.getEvidenceForClaim);
router.get('/:id', authenticate, validateParams(evidenceIdParamSchema), evidenceController.getEvidenceById);

router.post(
  '/',
  authenticate,
  authorize(USER_ROLES.CONTRIBUTOR),
  validateBody(createEvidenceSchema),
  evidenceController.submitEvidence
);

router.patch(
  '/:id/review',
  authenticate,
  authorize(USER_ROLES.REVIEWER),
  validateParams(evidenceIdParamSchema),
  validateBody(reviewEvidenceSchema),
  evidenceController.reviewEvidence
);

export default router;
