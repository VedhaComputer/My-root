import { Router } from 'express';
import { authController } from './controller';
import { validateBody } from '../../middleware/validateRequest';
import { authenticate } from '../../middleware/authenticate';
import {
  authRateLimiter,
  authRateLimitStore,
  authAccountRateLimiter,
  authAccountRateLimitStore,
} from '../../middleware/rateLimiter';
import {
  registerSchema,
  loginSchema,
  refreshSchema,
  logoutSchema,
  updateMeSchema,
  requestPasswordResetSchema,
  resetPasswordSchema,
  verifyEmailSchema,
  resendVerificationEmailSchema,
} from './validation';

const router = Router();

// Re-export rate limiters and stores for testing and backward compatibility
export {
  authRateLimiter,
  authRateLimitStore,
  authAccountRateLimiter,
  authAccountRateLimitStore,
};

// Endpoints with sensitive account identifiers: protected by both IP-based and Per-Account rate limiters
router.post('/register', authRateLimiter, authAccountRateLimiter, validateBody(registerSchema), authController.register);
router.post('/login', authRateLimiter, authAccountRateLimiter, validateBody(loginSchema), authController.login);
router.post('/password-reset/request', authRateLimiter, authAccountRateLimiter, validateBody(requestPasswordResetSchema), authController.requestPasswordReset);
router.post('/verify-email/resend', authRateLimiter, authAccountRateLimiter, validateBody(resendVerificationEmailSchema), authController.resendVerificationEmail);

// Token-based endpoints: protected by IP rate limiter
router.post('/refresh', authRateLimiter, validateBody(refreshSchema), authController.refreshToken);
router.post('/password-reset/confirm', authRateLimiter, validateBody(resetPasswordSchema), authController.resetPassword);
router.post('/verify-email', authRateLimiter, validateBody(verifyEmailSchema), authController.verifyEmail);

router.post('/logout', authenticate, validateBody(logoutSchema), authController.logout);
router.get('/me', authenticate, authController.getMe);
router.patch('/me', authenticate, validateBody(updateMeSchema), authController.updateMe);
router.patch('/me/selected-place', authenticate, validateBody(updateMeSchema), authController.updateMe);
router.get('/me/activity', authenticate, authController.getMyActivity);

export default router;
