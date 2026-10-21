import nodemailer from 'nodemailer';
import type { Transporter } from 'nodemailer';
import { IMailer, VerificationEmailPayload, PasswordResetEmailPayload, SentEmailRecord } from './types';
import { logger } from '../logger';

export class ConfigurationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ConfigurationError';
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/**
 * Escapes characters to prevent HTML injection in emails.
 */
export function escapeHtml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

export interface SmtpConfig {
  host: string;
  port: number;
  secure: boolean;
  auth: {
    user: string;
    pass: string;
  };
  from: string;
  connectionTimeout?: number;
  greetingTimeout?: number;
  socketTimeout?: number;
}

/**
 * Production SMTP transport using Nodemailer.
 * Encodes untrusted URLs and fields, and delivers multi-part HTML and plain text messages.
 * Never leaks raw credentials or tokens on connection or delivery failures.
 */
export class SmtpMailer implements IMailer {
  private transporter: Transporter;
  private from: string;
  private password?: string;

  constructor(config: SmtpConfig, transporter?: Transporter) {
    if (!config.host || !config.port || !config.auth?.user || !config.auth?.pass || !config.from || !config.from.trim()) {
      throw new ConfigurationError('SMTP configuration incomplete: host, port, user, pass, and from are required.');
    }
    if (/[\r\n]/.test(config.from)) {
      throw new ConfigurationError('Invalid EMAIL_FROM: newline characters are prohibited.');
    }
    this.from = config.from.trim();
    this.password = config.auth.pass;
    this.transporter =
      transporter ||
      nodemailer.createTransport({
        host: config.host,
        port: config.port,
        secure: config.secure,
        auth: {
          user: config.auth.user,
          pass: config.auth.pass,
        },
        connectionTimeout: config.connectionTimeout ?? 10000,
        greetingTimeout: config.greetingTimeout ?? 10000,
        socketTimeout: config.socketTimeout ?? 15000,
      });
  }

  /**
   * Verifies SMTP handshake and authentication readiness with the server
   * without dispatching any real emails.
   */
  async verifyConnection(): Promise<boolean> {
    if (typeof this.transporter.verify === 'function') {
      try {
        await this.transporter.verify();
        return true;
      } catch (err: any) {
        const sanitizedMessage = this.sanitizeError(err?.message || 'SMTP connection verification failed');
        const sanitizedError = new Error(sanitizedMessage);
        (sanitizedError as any).code = err?.code || 'SMTP_VERIFICATION_FAILED';
        throw sanitizedError;
      }
    }
    return true;
  }

  private sanitizeError(message: string): string {
    if (this.password && this.password.length > 0) {
      return message.split(this.password).join('***');
    }
    return message;
  }

  async sendVerificationEmail(payload: VerificationEmailPayload): Promise<void> {
    if (!payload.to || !payload.to.trim() || /[\r\n]/.test(payload.to)) {
      throw new ConfigurationError('Invalid recipient email address.');
    }
    const url = payload.verificationUrl || `http://localhost:3000/verify-email?token=${encodeURIComponent(payload.token)}`;
    const subject = 'Verify your email for My Root';
    const text = `Welcome to My Root!\n\nPlease verify your email address by opening the following link in your browser:\n${url}\n\nThis link will expire in 24 hours.\nIf you did not create an account on My Root, you can safely ignore this email.`;
    const html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Verify your email</title></head>
<body>
  <h2>Welcome to My Root</h2>
  <p>Please verify your email address by clicking the link below:</p>
  <p><a href="${escapeHtml(url)}">Verify My Email</a></p>
  <p>Or paste this link into your browser:<br><code>${escapeHtml(url)}</code></p>
  <p>This link expires in 24 hours. If you did not create this account, please ignore this email.</p>
</body>
</html>`;

    try {
      await this.transporter.sendMail({
        from: this.from,
        to: payload.to.trim(),
        subject,
        text,
        html,
      });
    } catch (err: any) {
      const sanitized = this.sanitizeError(err?.message || 'SMTP delivery failed');
      const deliveryErr = new Error(sanitized);
      (deliveryErr as any).code = err?.code || 'SMTP_DELIVERY_FAILED';
      throw deliveryErr;
    }
  }

  async sendPasswordResetEmail(payload: PasswordResetEmailPayload): Promise<void> {
    if (!payload.to || !payload.to.trim() || /[\r\n]/.test(payload.to)) {
      throw new ConfigurationError('Invalid recipient email address.');
    }
    const url = payload.resetUrl || `http://localhost:3000/reset-password?token=${encodeURIComponent(payload.token)}`;
    const subject = 'Password reset request for My Root';
    const text = `Hello,\n\nWe received a request to reset your password on My Root. You can reset your password using the link below:\n${url}\n\nThis link will expire in 1 hour.\nIf you did not request a password reset, you can safely ignore this email.`;
    const html = `<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><title>Password reset request</title></head>
<body>
  <h2>Password Reset Request</h2>
  <p>You requested a password reset for your My Root account. Click the link below to set a new password:</p>
  <p><a href="${escapeHtml(url)}">Reset Password</a></p>
  <p>Or paste this link into your browser:<br><code>${escapeHtml(url)}</code></p>
  <p>This link expires in 1 hour. If you did not request a password reset, please ignore this email.</p>
</body>
</html>`;

    try {
      await this.transporter.sendMail({
        from: this.from,
        to: payload.to.trim(),
        subject,
        text,
        html,
      });
    } catch (err: any) {
      const sanitized = this.sanitizeError(err?.message || 'SMTP delivery failed');
      const deliveryErr = new Error(sanitized);
      (deliveryErr as any).code = err?.code || 'SMTP_DELIVERY_FAILED';
      throw deliveryErr;
    }
  }
}

/**
 * TestMailer stores sent emails in memory for assertions in test suites.
 * Never performs network calls or leaks secrets externally.
 */
export class TestMailer implements IMailer {
  public sentEmails: SentEmailRecord[] = [];
  public shouldFail = false;
  public failureError = new Error('Simulated mail delivery failure');

  async sendVerificationEmail(payload: VerificationEmailPayload): Promise<void> {
    if (this.shouldFail) {
      throw this.failureError;
    }
    this.sentEmails.push({
      to: payload.to,
      subject: 'Verify your email for My Root',
      token: payload.token,
      url: payload.verificationUrl,
      sentAt: new Date(),
    });
  }

  async sendPasswordResetEmail(payload: PasswordResetEmailPayload): Promise<void> {
    if (this.shouldFail) {
      throw this.failureError;
    }
    this.sentEmails.push({
      to: payload.to,
      subject: 'Password reset request for My Root',
      token: payload.token,
      url: payload.resetUrl,
      sentAt: new Date(),
    });
  }

  async verifyConnection(): Promise<boolean> {
    if (this.shouldFail) {
      throw this.failureError;
    }
    return true;
  }

  clear(): void {
    this.sentEmails = [];
    this.shouldFail = false;
  }
}

/**
 * ConsoleMailer logs email notifications to stdout/logger for local development.
 * Strictly prohibited in production.
 */
export class ConsoleMailer implements IMailer {
  async sendVerificationEmail(payload: VerificationEmailPayload): Promise<void> {
    logger.info({ to: payload.to, subject: 'Verify your email for My Root' }, '[ConsoleMailer] Dispatched verification email');
  }

  async sendPasswordResetEmail(payload: PasswordResetEmailPayload): Promise<void> {
    logger.info({ to: payload.to, subject: 'Password reset request for My Root' }, '[ConsoleMailer] Dispatched password reset email');
  }

  async verifyConnection(): Promise<boolean> {
    return true;
  }
}

export interface MailerFactoryOptions {
  nodeEnv?: string;
  mailTransport?: string;
  customMailer?: IMailer;
  smtpConfig?: Partial<SmtpConfig>;
  transporter?: Transporter;
}

/**
 * Factory creating configured mailer transport.
 * Fails closed with ConfigurationError if production environment lacks an explicit, configured production transport.
 * Enforces SMTP-only transport in production, rejecting console, test, custom, and missing transports.
 * Custom mailer injection cannot bypass production safeguards, while preserving mock transporter injection for unit tests.
 */
export function createMailer(options: MailerFactoryOptions = {}): IMailer {
  const nodeEnv = options.nodeEnv ?? process.env.NODE_ENV ?? 'development';

  if (nodeEnv === 'production') {
    if (options.customMailer) {
      throw new ConfigurationError(
        'Custom mailer injection cannot bypass production startup validation. Production environment permits only MAIL_TRANSPORT=smtp.'
      );
    }

    const transport = options.mailTransport ?? process.env.MAIL_TRANSPORT;

    if (!transport || transport === 'console' || transport === 'test' || transport === 'custom' || transport === 'noop') {
      throw new ConfigurationError(
        'Production environment permits only MAIL_TRANSPORT=smtp. Transports "console", "test", "custom", or missing configuration are strictly prohibited.'
      );
    }

    if (transport !== 'smtp') {
      throw new ConfigurationError(
        `Unsupported production mail transport '${transport}'. Production environment permits only MAIL_TRANSPORT=smtp.`
      );
    }

    const host = options.smtpConfig?.host || process.env.SMTP_HOST;
    const port = options.smtpConfig?.port || (process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : 587);
    const secure =
      options.smtpConfig?.secure !== undefined
        ? options.smtpConfig.secure
        : process.env.SMTP_SECURE !== undefined
          ? process.env.SMTP_SECURE === 'true'
          : port === 465;
    const user = options.smtpConfig?.auth?.user || process.env.SMTP_USER;
    const pass = options.smtpConfig?.auth?.pass || process.env.SMTP_PASS;
    const from = options.smtpConfig?.from || process.env.EMAIL_FROM || 'noreply@myroot.in';
    const connectionTimeout =
      options.smtpConfig?.connectionTimeout ||
      (process.env.SMTP_TIMEOUT_MS ? Number(process.env.SMTP_TIMEOUT_MS) : 10000);

    if (!host || !user || !pass) {
      throw new ConfigurationError(
        'Production SMTP transport requires SMTP_HOST, SMTP_USER, and SMTP_PASS to be configured.'
      );
    }

    return new SmtpMailer(
      {
        host,
        port,
        secure,
        auth: { user, pass },
        from,
        connectionTimeout,
      },
      options.transporter
    );
  }

  if (options.customMailer) {
    return options.customMailer;
  }

  const transport = options.mailTransport ?? process.env.MAIL_TRANSPORT ?? (nodeEnv === 'test' ? 'test' : 'console');

  if (transport === 'test') {
    return new TestMailer();
  }

  if (transport === 'smtp') {
    const host = options.smtpConfig?.host || process.env.SMTP_HOST || 'localhost';
    const port = options.smtpConfig?.port || (process.env.SMTP_PORT ? Number(process.env.SMTP_PORT) : 587);
    const secure =
      options.smtpConfig?.secure !== undefined
        ? options.smtpConfig.secure
        : process.env.SMTP_SECURE !== undefined
          ? process.env.SMTP_SECURE === 'true'
          : port === 465;
    const user = options.smtpConfig?.auth?.user || process.env.SMTP_USER || 'testuser';
    const pass = options.smtpConfig?.auth?.pass || process.env.SMTP_PASS || 'testpass';
    const from = options.smtpConfig?.from || process.env.EMAIL_FROM || 'noreply@myroot.in';
    const connectionTimeout =
      options.smtpConfig?.connectionTimeout ||
      (process.env.SMTP_TIMEOUT_MS ? Number(process.env.SMTP_TIMEOUT_MS) : 10000);

    return new SmtpMailer(
      {
        host,
        port,
        secure,
        auth: { user, pass },
        from,
        connectionTimeout,
      },
      options.transporter
    );
  }

  return new ConsoleMailer();
}
