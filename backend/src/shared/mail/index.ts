import { createMailer } from './mailer.service';
import { env } from '../../config/env';

export * from './types';
export * from './mailer.service';

export const mailer = createMailer({
  nodeEnv: env.NODE_ENV,
  mailTransport: env.MAIL_TRANSPORT,
  smtpConfig: {
    host: env.SMTP_HOST,
    port: env.SMTP_PORT,
    secure: env.SMTP_SECURE,
    auth: {
      user: env.SMTP_USER || '',
      pass: env.SMTP_PASS || '',
    },
    from: env.EMAIL_FROM,
    connectionTimeout: env.SMTP_TIMEOUT_MS,
  },
});
