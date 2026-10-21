import { Router } from 'express';
import { placeController } from './controller';
import { validateBody, validateQuery, validateParams } from '../../middleware/validateRequest';
import { authenticate } from '../../middleware/authenticate';
import { authorize } from '../../middleware/authorize';
import { USER_ROLES } from '../../shared/constants';
import {
  createPlaceSchema,
  updatePlaceSchema,
  queryPlacesSchema,
  createPlaceAttributeSchema,
  correctPlaceAttributeSchema,
  placeIdParamSchema,
  placeAttrParamsSchema,
  getPlaceAttributesQuerySchema,
  reviewPlaceAttributeSchema,
} from './validation';

const router = Router();

router.get('/', authenticate, validateQuery(queryPlacesSchema), placeController.listPlaces);
router.get('/:id/children', authenticate, validateParams(placeIdParamSchema), placeController.getChildren);
router.get(
  '/:id/attributes',
  authenticate,
  validateParams(placeIdParamSchema),
  validateQuery(getPlaceAttributesQuerySchema),
  placeController.getPlaceAttributes
);
router.post(
  '/:id/attributes',
  authenticate,
  authorize(USER_ROLES.CONTRIBUTOR),
  validateParams(placeIdParamSchema),
  validateBody(createPlaceAttributeSchema),
  placeController.addPlaceAttribute
);
router.patch(
  '/:id/attributes/:attrId',
  authenticate,
  authorize(USER_ROLES.CONTRIBUTOR),
  validateParams(placeAttrParamsSchema),
  validateBody(correctPlaceAttributeSchema),
  placeController.correctPlaceAttribute
);
router.patch(
  '/:id/attributes/:attrId/review',
  authenticate,
  authorize(USER_ROLES.REVIEWER),
  validateParams(placeAttrParamsSchema),
  validateBody(reviewPlaceAttributeSchema),
  placeController.reviewPlaceAttribute
);
router.get('/:id/attributes/:attrId/history', authenticate, validateParams(placeAttrParamsSchema), placeController.getAttributeHistory);
router.get('/:id/progress', authenticate, validateParams(placeIdParamSchema), placeController.getPlaceProgress);
router.get('/:id', authenticate, validateParams(placeIdParamSchema), placeController.getPlaceById);

router.post(
  '/',
  authenticate,
  authorize(USER_ROLES.ADMIN),
  validateBody(createPlaceSchema),
  placeController.createPlace
);

router.put(
  '/:id',
  authenticate,
  authorize(USER_ROLES.MODERATOR),
  validateParams(placeIdParamSchema),
  validateBody(updatePlaceSchema),
  placeController.updatePlace
);

router.patch(
  '/:id',
  authenticate,
  authorize(USER_ROLES.MODERATOR),
  validateParams(placeIdParamSchema),
  validateBody(updatePlaceSchema),
  placeController.updatePlace
);

router.delete(
  '/:id',
  authenticate,
  authorize(USER_ROLES.ADMIN),
  validateParams(placeIdParamSchema),
  placeController.deletePlace
);

export default router;
