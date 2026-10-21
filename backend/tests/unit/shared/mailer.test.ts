import {
  createMailer,
  TestMailer,
  ConsoleMailer,
  SmtpMailer,
  ConfigurationError,
  escapeHtml,
} from '../../../src/shared/mail';
import { envSchema } from '../../../src/config/env';
import { logger } from '../../../src/shared/logger';

describe('Mailer Service and Factory', () => {
  describe('escapeHtml', () => {
    it('escapes dangerous characters to prevent HTML injection', () => {
      const dangerous = '<script>alert("xss & \'injection\'")</script>';
      const safe = escapeHtml(dangerous);
      expect(safe).toBe('&lt;script&gt;alert(&quot;xss &amp; &#039;injection&#039;&quot;)&lt;/script&gt;');
    });
  });

  describe('SmtpMailer', () => {
    let mockTransporter: any;
    const sampleConfig = {
      host: 'smtp.example.com',
      port: 587,
      secure: false,
      auth: {
        user: 'mailer_user',
        pass: 'mailer_pass',
      },
      from: 'noreply@myroot.in',
    };

    beforeEach(() => {
      mockTransporter = {
        sendMail: jest.fn().mockResolvedValue({ messageId: 'msg-123' }),
      };
    });

    it('throws ConfigurationError if required config is missing', () => {
      expect(() => new SmtpMailer({} as any)).toThrow(ConfigurationError);
      expect(() => new SmtpMailer({ host: 'smtp.example.com' } as any)).toThrow(ConfigurationError);
    });

    it('throws ConfigurationError if EMAIL_FROM contains newline characters', () => {
      expect(
        () =>
          new SmtpMailer({
            ...sampleConfig,
            from: 'noreply@myroot.in\r\nBcc: evil@attacker.com',
          })
      ).toThrow(ConfigurationError);
    });

    it('rejects recipient email addresses with newline injection attempts', async () => {
      const mailer = new SmtpMailer(sampleConfig, mockTransporter);
      await expect(
        mailer.sendVerificationEmail({
          to: 'attacker@example.com\r\nBcc: victim@example.com',
          token: 'token123',
        })
      ).rejects.toThrow('Invalid recipient email address');

      await expect(
        mailer.sendPasswordResetEmail({
          to: 'attacker@example.com\nBcc: victim@example.com',
          token: 'token123',
        })
      ).rejects.toThrow('Invalid recipient email address');
    });

    it('successfully sends verification email with multi-part HTML, text, and encoded URL', async () => {
      const mailer = new SmtpMailer(sampleConfig, mockTransporter);
      await mailer.sendVerificationEmail({
        to: 'recipient@example.com',
        token: 'verify_token_123',
        verificationUrl: 'https://myroot.in/verify?token=verify_token_123&test=1',
      });

      expect(mockTransporter.sendMail).toHaveBeenCalledTimes(1);
      const callArg = mockTransporter.sendMail.mock.calls[0][0];
      expect(callArg.from).toBe('noreply@myroot.in');
      expect(callArg.to).toBe('recipient@example.com');
      expect(callArg.subject).toContain('Verify your email');
      expect(callArg.text).toContain('https://myroot.in/verify?token=verify_token_123&test=1');
      expect(callArg.html).toContain('href="https://myroot.in/verify?token=verify_token_123&amp;test=1"');
      expect(callArg.html).toContain('Verify My Email');
    });

    it('successfully sends password reset email with multi-part HTML, text, and encoded URL', async () => {
      const mailer = new SmtpMailer(sampleConfig, mockTransporter);
      await mailer.sendPasswordResetEmail({
        to: 'reset_recipient@example.com',
        token: 'reset_token_456',
        resetUrl: 'https://myroot.in/reset?token=reset_token_456',
      });

      expect(mockTransporter.sendMail).toHaveBeenCalledTimes(1);
      const callArg = mockTransporter.sendMail.mock.calls[0][0];
      expect(callArg.from).toBe('noreply@myroot.in');
      expect(callArg.to).toBe('reset_recipient@example.com');
      expect(callArg.subject).toContain('Password reset request');
      expect(callArg.text).toContain('https://myroot.in/reset?token=reset_token_456');
      expect(callArg.html).toContain('href="https://myroot.in/reset?token=reset_token_456"');
      expect(callArg.html).toContain('Reset Password');
    });

    it('propagates transporter delivery failure and redacts secret password if present in message', async () => {
      mockTransporter.sendMail.mockRejectedValueOnce(
        new Error('Auth failed for user mailer_user with password mailer_pass: 535 authentication failed')
      );
      const mailer = new SmtpMailer(sampleConfig, mockTransporter);

      await expect(
        mailer.sendVerificationEmail({
          to: 'recipient@example.com',
          token: 'token123',
        })
      ).rejects.toThrow('Auth failed for user mailer_user with password ***: 535 authentication failed');
    });

    it('verifyConnection executes transporter verify handshake without sending email', async () => {
      mockTransporter.verify = jest.fn().mockResolvedValue(true);
      const mailer = new SmtpMailer(sampleConfig, mockTransporter);

      const isReady = await mailer.verifyConnection();
      expect(isReady).toBe(true);
      expect(mockTransporter.verify).toHaveBeenCalledTimes(1);
      expect(mockTransporter.sendMail).not.toHaveBeenCalled();
    });

    it('verifyConnection redacts credentials if handshake verification fails', async () => {
      mockTransporter.verify = jest.fn().mockRejectedValue(
        new Error('Connection error with pass mailer_pass to host smtp.example.com')
      );
      const mailer = new SmtpMailer(sampleConfig, mockTransporter);

      await expect(mailer.verifyConnection()).rejects.toThrow(
        'Connection error with pass *** to host smtp.example.com'
      );
    });
  });

  describe('TestMailer', () => {
    let testMailer: TestMailer;

    beforeEach(() => {
      testMailer = new TestMailer();
    });

    it('records dispatched verification email without network call', async () => {
      await testMailer.sendVerificationEmail({
        to: 'user@example.com',
        token: 'raw-token-12345',
        verificationUrl: 'http://localhost:3000/verify-email?token=raw-token-12345',
      });

      expect(testMailer.sentEmails).toHaveLength(1);
      expect(testMailer.sentEmails[0].to).toBe('user@example.com');
      expect(testMailer.sentEmails[0].token).toBe('raw-token-12345');
      expect(testMailer.sentEmails[0].url).toContain('token=raw-token-12345');
    });

    it('records dispatched password reset email without network call', async () => {
      await testMailer.sendPasswordResetEmail({
        to: 'reset@example.com',
        token: 'reset-token-67890',
        resetUrl: 'http://localhost:3000/reset-password?token=reset-token-67890',
      });

      expect(testMailer.sentEmails).toHaveLength(1);
      expect(testMailer.sentEmails[0].to).toBe('reset@example.com');
      expect(testMailer.sentEmails[0].token).toBe('reset-token-67890');
      expect(testMailer.sentEmails[0].url).toContain('token=reset-token-67890');
    });

    it('fails closed when shouldFail is set to simulate delivery failure', async () => {
      testMailer.shouldFail = true;

      await expect(
        testMailer.sendVerificationEmail({
          to: 'fail@example.com',
          token: 'token-fail',
        })
      ).rejects.toThrow('Simulated mail delivery failure');

      await expect(
        testMailer.sendPasswordResetEmail({
          to: 'fail@example.com',
          token: 'token-fail',
        })
      ).rejects.toThrow('Simulated mail delivery failure');
    });

    it('clear() resets stored emails and failure flag', async () => {
      await testMailer.sendVerificationEmail({ to: 'a@b.com', token: 't1' });
      testMailer.shouldFail = true;

      testMailer.clear();

      expect(testMailer.sentEmails).toHaveLength(0);
      expect(testMailer.shouldFail).toBe(false);
    });

    it('verifyConnection succeeds in normal state and fails when shouldFail is true', async () => {
      await expect(testMailer.verifyConnection()).resolves.toBe(true);

      testMailer.shouldFail = true;
      await expect(testMailer.verifyConnection()).rejects.toThrow('Simulated mail delivery failure');
    });
  });

  describe('ConsoleMailer', () => {
    it('dispatches emails via logger.info in non-production environments', async () => {
      const consoleMailer = new ConsoleMailer();
      const loggerInfoSpy = jest.spyOn(logger, 'info').mockImplementation(() => logger as any);

      await consoleMailer.sendVerificationEmail({ to: 'log@example.com', token: 'tok-123' });
      expect(loggerInfoSpy).toHaveBeenCalledWith(
        expect.objectContaining({ to: 'log@example.com' }),
        expect.stringContaining('[ConsoleMailer]')
      );

      await consoleMailer.sendPasswordResetEmail({ to: 'log@example.com', token: 'tok-456' });
      expect(loggerInfoSpy).toHaveBeenCalledWith(
        expect.objectContaining({ to: 'log@example.com' }),
        expect.stringContaining('[ConsoleMailer]')
      );

      loggerInfoSpy.mockRestore();
    });

    it('verifyConnection resolves to true without network calls', async () => {
      const consoleMailer = new ConsoleMailer();
      await expect(consoleMailer.verifyConnection()).resolves.toBe(true);
    });
  });

  describe('createMailer Factory Environment Rules', () => {
    it('returns TestMailer for test environment', () => {
      const mailer = createMailer({ nodeEnv: 'test', mailTransport: 'test' });
      expect(mailer).toBeInstanceOf(TestMailer);
    });

    it('returns ConsoleMailer for development environment', () => {
      const mailer = createMailer({ nodeEnv: 'development', mailTransport: 'console' });
      expect(mailer).toBeInstanceOf(ConsoleMailer);
    });

    it('returns custom injected mailer in non-production environments', () => {
      const customMailer = new TestMailer();
      const devMailer = createMailer({ nodeEnv: 'development', customMailer });
      expect(devMailer).toBe(customMailer);

      const testMailer = createMailer({ nodeEnv: 'test', customMailer });
      expect(testMailer).toBe(customMailer);
    });

    it('rejects custom mailer injection in production to prevent startup bypass', () => {
      const customMailer = new TestMailer();
      expect(() => {
        createMailer({ nodeEnv: 'production', customMailer });
      }).toThrow(ConfigurationError);

      expect(() => {
        createMailer({ nodeEnv: 'production', customMailer });
      }).toThrow(/Custom mailer injection cannot bypass production startup validation/i);
    });

    it('rejects console transport in production with ConfigurationError', () => {
      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'console' });
      }).toThrow(ConfigurationError);

      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'console' });
      }).toThrow(/strictly prohibited/i);
    });

    it('rejects test transport in production with ConfigurationError', () => {
      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'test' });
      }).toThrow(ConfigurationError);

      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'test' });
      }).toThrow(/strictly prohibited/i);
    });

    it('rejects custom transport in production with ConfigurationError', () => {
      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'custom' });
      }).toThrow(ConfigurationError);

      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'custom' });
      }).toThrow(/strictly prohibited/i);
    });

    it('rejects missing or empty transport in production', () => {
      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: '' });
      }).toThrow(ConfigurationError);

      const oldEnv = process.env.MAIL_TRANSPORT;
      delete process.env.MAIL_TRANSPORT;
      try {
        expect(() => {
          createMailer({ nodeEnv: 'production' });
        }).toThrow(ConfigurationError);
      } finally {
        if (oldEnv !== undefined) {
          process.env.MAIL_TRANSPORT = oldEnv;
        }
      }
    });

    it('rejects unconfigured production smtp transport when required credentials are missing', () => {
      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'smtp' });
      }).toThrow(ConfigurationError);

      expect(() => {
        createMailer({ nodeEnv: 'production', mailTransport: 'smtp' });
      }).toThrow(/requires SMTP_HOST, SMTP_USER, and SMTP_PASS/i);
    });

    it('rejects production smtp transport when individual required fields are missing', () => {
      // Missing host
      expect(() => {
        createMailer({
          nodeEnv: 'production',
          mailTransport: 'smtp',
          smtpConfig: { auth: { user: 'u', pass: 'p' }, from: 'a@b.com' },
        });
      }).toThrow(/requires SMTP_HOST, SMTP_USER, and SMTP_PASS/i);

      // Missing user
      expect(() => {
        createMailer({
          nodeEnv: 'production',
          mailTransport: 'smtp',
          smtpConfig: { host: 'smtp.example.com', auth: { user: '', pass: 'p' }, from: 'a@b.com' },
        });
      }).toThrow(/requires SMTP_HOST, SMTP_USER, and SMTP_PASS/i);

      // Missing pass
      expect(() => {
        createMailer({
          nodeEnv: 'production',
          mailTransport: 'smtp',
          smtpConfig: { host: 'smtp.example.com', auth: { user: 'u', pass: '' }, from: 'a@b.com' },
        });
      }).toThrow(/requires SMTP_HOST, SMTP_USER, and SMTP_PASS/i);
    });

    it('successfully creates SmtpMailer in production when SMTP credentials and host are configured', () => {
      const mockTransporter: any = { sendMail: jest.fn() };
      const mailer = createMailer({
        nodeEnv: 'production',
        mailTransport: 'smtp',
        smtpConfig: {
          host: 'smtp.prod.net',
          port: 587,
          secure: false,
          auth: { user: 'prod_user', pass: 'prod_pass' },
          from: 'noreply@myroot.in',
        },
        transporter: mockTransporter,
      });

      expect(mailer).toBeInstanceOf(SmtpMailer);
    });

    it('defaults secure to true for port 465 and false for port 587 when secure is omitted', () => {
      const mockTransporter: any = { sendMail: jest.fn() };
      const mailer465 = createMailer({
        nodeEnv: 'development',
        mailTransport: 'smtp',
        smtpConfig: {
          host: 'smtp.example.com',
          port: 465,
          auth: { user: 'u', pass: 'p' },
          from: 'noreply@myroot.in',
        },
        transporter: mockTransporter,
      });
      expect(mailer465).toBeInstanceOf(SmtpMailer);

      const mailer587 = createMailer({
        nodeEnv: 'development',
        mailTransport: 'smtp',
        smtpConfig: {
          host: 'smtp.example.com',
          port: 587,
          auth: { user: 'u', pass: 'p' },
          from: 'noreply@myroot.in',
        },
        transporter: mockTransporter,
      });
      expect(mailer587).toBeInstanceOf(SmtpMailer);
    });

    it('honors explicit secure flag override regardless of port', () => {
      const mockTransporter: any = { sendMail: jest.fn() };
      const mailerExplicit = createMailer({
        nodeEnv: 'development',
        mailTransport: 'smtp',
        smtpConfig: {
          host: 'smtp.example.com',
          port: 587,
          secure: true,
          auth: { user: 'u', pass: 'p' },
          from: 'noreply@myroot.in',
        },
        transporter: mockTransporter,
      });
      expect(mailerExplicit).toBeInstanceOf(SmtpMailer);
    });

    it('passes custom connectionTimeout to SmtpMailer from options', () => {
      const mockTransporter: any = { sendMail: jest.fn() };
      const mailer = createMailer({
        nodeEnv: 'development',
        mailTransport: 'smtp',
        smtpConfig: {
          host: 'smtp.example.com',
          port: 587,
          auth: { user: 'u', pass: 'p' },
          from: 'noreply@myroot.in',
          connectionTimeout: 15000,
        },
        transporter: mockTransporter,
      });
      expect(mailer).toBeInstanceOf(SmtpMailer);
    });
  });

  describe('Environment Schema Refinement (envSchema)', () => {
    const baseEnv = {
      PORT: '3001',
      MONGODB_URI: 'mongodb://localhost:27017/myroot',
      JWT_ACCESS_SECRET: 'a'.repeat(64),
      JWT_REFRESH_SECRET: 'b'.repeat(64),
      PLACE_API_PROXY_ENABLED: 'false',
    };

    it('accepts console transport in development', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        NODE_ENV: 'development',
        MAIL_TRANSPORT: 'console',
      });
      expect(result.success).toBe(true);
    });

    it('accepts test transport in test', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        NODE_ENV: 'test',
        MAIL_TRANSPORT: 'test',
      });
      expect(result.success).toBe(true);
    });

    it('refuses console transport in production schema validation', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        NODE_ENV: 'production',
        MAIL_TRANSPORT: 'console',
      });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toContain('Production environment permits only MAIL_TRANSPORT=smtp');
      }
    });

    it('refuses test transport in production schema validation', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        NODE_ENV: 'production',
        MAIL_TRANSPORT: 'test',
      });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toContain('Production environment permits only MAIL_TRANSPORT=smtp');
      }
    });

    it('refuses custom transport in production schema validation', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        NODE_ENV: 'production',
        MAIL_TRANSPORT: 'custom',
      });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues[0].message).toContain('Production environment permits only MAIL_TRANSPORT=smtp');
      }
    });

    it('refuses production smtp transport when required SMTP credentials or host are missing', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        NODE_ENV: 'production',
        MAIL_TRANSPORT: 'smtp',
        SMTP_HOST: 'smtp.example.com',
        // Missing SMTP_USER and SMTP_PASS
      });
      expect(result.success).toBe(false);
    });

    it('accepts production smtp transport when full SMTP configuration is present', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        NODE_ENV: 'production',
        MAIL_TRANSPORT: 'smtp',
        SMTP_HOST: 'smtp.example.com',
        SMTP_PORT: '587',
        SMTP_USER: 'prod_user',
        SMTP_PASS: 'prod_pass',
        EMAIL_FROM: 'noreply@myroot.in',
      });
      expect(result.success).toBe(true);
    });

    it('refuses EMAIL_FROM with CRLF newline injection', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        EMAIL_FROM: 'noreply@myroot.in\r\nBcc: evil@attacker.com',
      });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('EMAIL_FROM'))).toBe(true);
      }
    });

    it('refuses EMAIL_FROM with invalid email structure', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        EMAIL_FROM: 'not-an-email',
      });
      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.error.issues.some((i) => i.path.includes('EMAIL_FROM'))).toBe(true);
      }
    });

    it('accepts RFC formatted EMAIL_FROM with display name and email address', () => {
      const result = envSchema.safeParse({
        ...baseEnv,
        EMAIL_FROM: 'My Root Admin <admin@myroot.in>',
      });
      expect(result.success).toBe(true);
    });

    it('validates SMTP_TIMEOUT_MS and refuses values below 500ms', () => {
      const validResult = envSchema.safeParse({
        ...baseEnv,
        SMTP_TIMEOUT_MS: '15000',
      });
      expect(validResult.success).toBe(true);
      if (validResult.success) {
        expect(validResult.data.SMTP_TIMEOUT_MS).toBe(15000);
      }

      const invalidResult = envSchema.safeParse({
        ...baseEnv,
        SMTP_TIMEOUT_MS: '200',
      });
      expect(invalidResult.success).toBe(false);
    });
  });
});
