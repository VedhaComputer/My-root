import { Router } from 'express';
import { claimController } from './controller';
import { validateBody, validateQuery, validateParams } from '../../middleware/validateRequest';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { USER_ROLES } from '../../shared/constants';
import {
  createClaimSchema,
  updateClaimSchema,
  queryClaimsSchema,
  requestCorrectionSchema,
  verifyConsentSchema,
  reviewCorrectionSchema,
  reviewClaimSchema,
  claimIdParamSchema,
  claimCorrectionParamsSchema,
  submitHistoryFeedbackSchema,
} from './validation';

const router = Router();

router.get('/', authenticate, validateQuery(queryClaimsSchema), claimController.listClaims);
router.get(
  '/review-queue',
  authenticate,
  authorize(USER_ROLES.REVIEWER),
  validateQuery(queryClaimsSchema),
  claimController.getReviewQueue
);
router.get('/:id/corrections', authenticate, validateParams(claimIdParamSchema), claimController.getCorrections);
router.get('/:id', authenticate, validateParams(claimIdParamSchema), claimController.getClaimById);

router.post(
  '/',
  authenticate,
  authorize(USER_ROLES.CONTRIBUTOR),
  validateBody(createClaimSchema),
  claimController.createClaim
);

router.patch(
  '/:id/submit',
  authenticate,
  validateParams(claimIdParamSchema),
  claimController.submitClaim
);

router.post(
  '/:id/review',
  authenticate,
  authorize(USER_ROLES.REVIEWER),
  validateParams(claimIdParamSchema),
  validateBody(reviewClaimSchema),
  claimController.reviewClaim
);

router.patch(
  '/:id/consent',
  authenticate,
  authorize(USER_ROLES.REVIEWER),
  validateParams(claimIdParamSchema),
  validateBody(verifyConsentSchema),
  claimController.verifyConsent
);

router.post(
  '/:id/correction',
  authenticate,
  authorize(USER_ROLES.CONTRIBUTOR),
  validateParams(claimIdParamSchema),
  validateBody(requestCorrectionSchema),
  claimController.requestCorrection
);

router.patch(
  '/:id/corrections/:correctionId/review',
  authenticate,
  authorize(USER_ROLES.REVIEWER),
  validateParams(claimCorrectionParamsSchema),
  validateBody(reviewCorrectionSchema),
  claimController.reviewCorrection
);

router.post(
  '/:id/feedback',
  authenticate,
  validateParams(claimIdParamSchema),
  validateBody(submitHistoryFeedbackSchema),
  claimController.submitFeedback
);

router.patch(
  '/:id',
  authenticate,
  validateParams(claimIdParamSchema),
  validateBody(updateClaimSchema),
  claimController.updateClaim
);

router.delete(
  '/:id',
  authenticate,
  authorize(USER_ROLES.MODERATOR),
  validateParams(claimIdParamSchema),
  claimController.archiveClaim
);

export default router;
