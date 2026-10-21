import { Router } from 'express';
import { verificationController } from './controller';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { validateBody, validateParams } from '../../middleware/validateRequest';
import { submitReviewSchema, verificationClaimIdParamSchema } from './validation';
import { USER_ROLES } from '../../shared/constants';

const router = Router();

router.get('/claim/:claimId', authenticate, validateParams(verificationClaimIdParamSchema), verificationController.getReviewsForClaim);

router.post(
  '/',
  authenticate,
  authorize(USER_ROLES.REVIEWER),
  validateBody(submitReviewSchema),
  verificationController.submitReview
);

export default router;
