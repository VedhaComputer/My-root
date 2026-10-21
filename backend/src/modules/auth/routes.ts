import { Router } from 'express';
import rateLimit, { MemoryStore } from 'express-rate-limit';
import { env } from '../../config/env';
import { authController } from './controller';
import { validateBody } from '../../middleware/validateRequest';
import { authenticate } from '../../middleware/authenticate';
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  logoutSchema,
  updateMeSchema,
  requestPasswordResetSchema,
  resetPasswordSchema,
  verifyEmailSchema,
} from './validation';

const router = Router();

// Dedicated configurable rate limit store and middleware for sensitive authentication endpoints
export const authRateLimitStore = new MemoryStore();

export const authRateLimiter = rateLimit({
  windowMs: env.AUTH_RATE_LIMIT_WINDOW_MS,
  max: env.AUTH_RATE_LIMIT_MAX,
  standardHeaders: true,
  legacyHeaders: false,
  store: authRateLimitStore,
  message: { error: { code: 'RATE_LIMITED', message: 'Too many authentication attempts. Please try again later.' } },
});

router.post('/register', authRateLimiter, validateBody(registerSchema), authController.register);
router.post('/login', authRateLimiter, validateBody(loginSchema), authController.login);
router.post('/refresh', authRateLimiter, validateBody(refreshSchema), authController.refreshToken);
router.post('/password-reset/request', authRateLimiter, validateBody(requestPasswordResetSchema), authController.requestPasswordReset);
router.post('/password-reset/confirm', authRateLimiter, validateBody(resetPasswordSchema), authController.resetPassword);
router.post('/verify-email', authRateLimiter, validateBody(verifyEmailSchema), authController.verifyEmail);

router.post('/logout', authenticate, validateBody(logoutSchema), authController.logout);
router.get('/me', authenticate, authController.getMe);
router.patch('/me', authenticate, validateBody(updateMeSchema), authController.updateMe);
router.patch('/me/selected-place', authenticate, validateBody(updateMeSchema), authController.updateMe);
router.get('/me/activity', authenticate, authController.getMyActivity);

export default router;
