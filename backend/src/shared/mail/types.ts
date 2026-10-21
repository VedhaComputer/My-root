export interface VerificationEmailPayload {
  to: string;
  token: string;
  verificationUrl?: string;
}

export interface PasswordResetEmailPayload {
  to: string;
  token: string;
  resetUrl?: string;
}

export interface SentEmailRecord {
  to: string;
  subject: string;
  token: string;
  url?: string;
  sentAt: Date;
}

export interface IMailer {
  sendVerificationEmail(payload: VerificationEmailPayload): Promise<void>;
  sendPasswordResetEmail(payload: PasswordResetEmailPayload): Promise<void>;
  verifyConnection?(): Promise<boolean>;
}
