import { Router } from 'express';
import { pollController } from './controller';
import { validateBody, validateQuery, validateParams } from '../../middleware/validateRequest';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { USER_ROLES } from '../../shared/constants';
import {
  createPollSchema,
  votePollSchema,
  queryPollsSchema,
  reportPollSchema,
  moderatePollSchema,
  pollIdParamSchema,
} from './validation';

const router = Router();

router.get('/', authenticate, validateQuery(queryPollsSchema), pollController.listPolls);
router.post('/', authenticate, validateBody(createPollSchema), pollController.createPoll);
router.get('/:id', authenticate, validateParams(pollIdParamSchema), pollController.getPollById);
router.post(
  '/:id/vote',
  authenticate,
  validateParams(pollIdParamSchema),
  validateBody(votePollSchema),
  pollController.castVote
);
router.post(
  '/:id/close',
  authenticate,
  validateParams(pollIdParamSchema),
  pollController.closePoll
);
router.post(
  '/:id/report',
  authenticate,
  validateParams(pollIdParamSchema),
  validateBody(reportPollSchema),
  pollController.reportPoll
);
router.post(
  '/:id/moderate',
  authenticate,
  authorize(USER_ROLES.MODERATOR),
  validateParams(pollIdParamSchema),
  validateBody(moderatePollSchema),
  pollController.moderatePoll
);

export default router;
