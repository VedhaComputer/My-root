import mongoose from 'mongoose';
import { UserModel, IUser, hashEmail } from './user.model';
import { RefreshTokenModel, IRefreshToken, hashToken } from './refreshToken.model';
import { UserRole } from '../../shared/constants';
import { NotFoundError, ServiceUnavailableError } from '../../shared/errors/AppError';

export interface CreateUserData {
  displayName: string;
  email: string;
  passwordHash: string;
  role?: UserRole;
}

export class AuthRepository {
  async createUser(data: CreateUserData): Promise<IUser> {
    const emailHash = hashEmail(data.email);
    const user = new UserModel({
      displayName: data.displayName,
      email: data.email.trim().toLowerCase(),
      emailHash,
      passwordHash: data.passwordHash,
      role: data.role,
    });
    return await user.save();
  }

  async emailExists(email: string): Promise<boolean> {
    const emailHash = hashEmail(email);
    const count = await UserModel.countDocuments({ emailHash });
    return count > 0;
  }

  async findByEmailWithSecrets(email: string): Promise<IUser | null> {
    const emailHash = hashEmail(email);
    return await UserModel.findOne({ emailHash })
      .select('+passwordHash +email +emailHash')
      .exec();
  }

  async findById(id: string): Promise<IUser | null> {
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return null;
    }
    return await UserModel.findById(id).exec();
  }

  async saveRefreshToken(
    userId: string,
    token: string,
    expiresAt: Date,
    tokenFamily: string,
    replacedByTokenHash: string | null = null
  ): Promise<IRefreshToken> {
    const tokenHash = hashToken(token);
    if (mongoose.connection.readyState !== 1) {
      throw new ServiceUnavailableError('Authentication service unavailable: database disconnected');
    }
    const doc = new RefreshTokenModel({
      userId: new mongoose.Types.ObjectId(userId),
      tokenHash,
      tokenFamily,
      replacedByTokenHash,
      expiresAt,
      revoked: false,
    });
    return await doc.save();
  }

  async findTokenByHash(token: string): Promise<IRefreshToken | null> {
    if (mongoose.connection.readyState !== 1) {
      return null;
    }
    const tokenHash = hashToken(token);
    return await RefreshTokenModel.findOne({ tokenHash }).exec();
  }

  async findActiveRefreshToken(token: string): Promise<IRefreshToken | null> {
    if (mongoose.connection.readyState !== 1) {
      return null;
    }
    const tokenHash = hashToken(token);
    return await RefreshTokenModel.findOne({
      tokenHash,
      revoked: false,
      expiresAt: { $gt: new Date() },
    }).exec();
  }

  public supportsTransactions(): boolean {
    try {
      if (mongoose.connection.readyState !== 1) {
        return false;
      }
      const client = mongoose.connection.getClient() as any;
      const desc = client?.topology?.description;
      if (!desc || desc.compatibilityError) {
        return false;
      }
      const type = desc.type;
      if (type === 'ReplicaSetWithPrimary' || type === 'Sharded') {
        return true;
      }
      if (type === 'Single' && desc.servers) {
        for (const server of desc.servers.values()) {
          if (server?.type === 'RSPrimary') {
            return true;
          }
        }
      }
      return false;
    } catch {
      return false;
    }
  }

  /**
   * Atomically rotates an old refresh token and persists its replacement inside a single
   * MongoDB ACID multi-document transaction when supported by the topology.
   * If transactions are not supported, executes atomic rotation first; if replacement persistence
   * fails, leaves the old token revoked (fail closed) to eliminate dual-active token risks.
   */
  async rotateAndSaveRefreshToken(
    oldToken: string,
    newToken: string,
    userId: string,
    expiresAt: Date,
    tokenFamily: string
  ): Promise<{ rotated: boolean; replacement: IRefreshToken | null }> {
    if (mongoose.connection.readyState !== 1) {
      return { rotated: false, replacement: null };
    }

    if (this.supportsTransactions()) {
      const session = await mongoose.startSession();
      try {
        let rotated = false;
        let replacementDoc: IRefreshToken | null = null;

        await session.withTransaction(
          async () => {
            rotated = false;
            replacementDoc = null;

            const oldTokenHash = hashToken(oldToken);
            const newTokenHash = hashToken(newToken);

            const rotatedDoc = await RefreshTokenModel.findOneAndUpdate(
              {
                tokenHash: oldTokenHash,
                revoked: false,
                expiresAt: { $gt: new Date() },
              },
              {
                $set: {
                  revoked: true,
                  replacedByTokenHash: newTokenHash,
                },
              },
              { new: true, session }
            ).exec();

            if (!rotatedDoc) {
              rotated = false;
              return;
            }

            rotated = true;

            const [doc] = await RefreshTokenModel.create(
              [
                {
                  userId: new mongoose.Types.ObjectId(userId),
                  tokenHash: newTokenHash,
                  tokenFamily,
                  replacedByTokenHash: null,
                  expiresAt,
                  revoked: false,
                },
              ],
              { session }
            );

            replacementDoc = doc;
          },
          {
            readPreference: 'primary',
            readConcern: { level: 'local' },
            writeConcern: { w: 'majority' },
          }
        );

        return { rotated, replacement: replacementDoc };
      } catch (error: any) {
        if (
          error?.code === 20 ||
          error?.codeName === 'IllegalOperation' ||
          (typeof error?.message === 'string' &&
            error.message.includes('Transaction numbers are only allowed on a replica set member or mongos'))
        ) {
          // Fall through to non-transactional fallback if topology check had false positive
        } else {
          throw error;
        }
      } finally {
        await session.endSession();
      }
    }

    // Non-transactional fallback (Standalone MongoDB / development):
    const rotatedDoc = await this.atomicRotateRefreshToken(oldToken, newToken);
    if (!rotatedDoc) {
      return { rotated: false, replacement: null };
    }

    // Note: If saveRefreshToken throws on standalone MongoDB, cross-document rollback cannot
    // be proven atomic; oldToken remains revoked (fail closed) to eliminate dual-active token risks.
    const doc = await this.saveRefreshToken(userId, newToken, expiresAt, tokenFamily);
    return { rotated: true, replacement: doc };
  }

  /**
   * Atomically rotates a refresh token.
   * Finds the active token matching tokenHash (with revoked: false and expiresAt > now)
   * and marks it revoked: true, setting replacedByTokenHash.
   * If another concurrent request already rotated it, findOneAndUpdate returns null!
   */
  async atomicRotateRefreshToken(
    oldToken: string,
    newToken: string
  ): Promise<IRefreshToken | null> {
    if (mongoose.connection.readyState !== 1) {
      return null;
    }
    const oldTokenHash = hashToken(oldToken);
    const newTokenHash = hashToken(newToken);
    return await RefreshTokenModel.findOneAndUpdate(
      {
        tokenHash: oldTokenHash,
        revoked: false,
        expiresAt: { $gt: new Date() },
      },
      {
        $set: {
          revoked: true,
          replacedByTokenHash: newTokenHash,
        },
      },
      { new: true }
    ).exec();
  }

  async findByStoredTokenHash(tokenHash: string): Promise<IRefreshToken | null> {
    if (mongoose.connection.readyState !== 1) {
      return null;
    }
    return await RefreshTokenModel.findOne({ tokenHash }).exec();
  }

  async rollbackTokenRotation(
    token: string,
    expectedReplacedByTokenHash?: string | null
  ): Promise<boolean> {
    if (mongoose.connection.readyState !== 1) {
      return false;
    }
    const tokenHash = hashToken(token);

    if (expectedReplacedByTokenHash) {
      // Step 1: Pre-check: Verify replacement token was not already persisted.
      const replacementExists = await RefreshTokenModel.exists({
        tokenHash: expectedReplacedByTokenHash,
      }).exec();
      if (replacementExists) {
        return false;
      }

      // Step 2: Atomic update conditional on revoked: true and matching replacedByTokenHash.
      const result = await RefreshTokenModel.updateOne(
        {
          tokenHash,
          revoked: true,
          replacedByTokenHash: expectedReplacedByTokenHash,
        },
        {
          $set: {
            revoked: false,
            replacedByTokenHash: null,
          },
        }
      ).exec();

      if (result.modifiedCount === 0) {
        return false;
      }

      // Step 3: TOCTOU Post-Verification Guard:
      // Check whether the replacement token was persisted concurrently in the interleaving window
      const postCheckExists = await RefreshTokenModel.exists({
        tokenHash: expectedReplacedByTokenHash,
      }).exec();

      if (postCheckExists) {
        // Concurrency violation detected: replacement was persisted concurrently!
        // Immediately re-revoke the old token to restore the fail-closed invariant.
        await RefreshTokenModel.updateOne(
          {
            tokenHash,
            revoked: false,
          },
          {
            $set: {
              revoked: true,
              replacedByTokenHash: expectedReplacedByTokenHash,
            },
          }
        ).exec();
        return false;
      }

      return true;
    }

    const currentDoc = await RefreshTokenModel.findOne({ tokenHash, revoked: true }).exec();
    if (currentDoc && currentDoc.replacedByTokenHash) {
      const targetHash = currentDoc.replacedByTokenHash;
      const replacementExists = await RefreshTokenModel.exists({
        tokenHash: targetHash,
      }).exec();
      if (replacementExists) {
        return false;
      }
      const result = await RefreshTokenModel.updateOne(
        {
          tokenHash,
          revoked: true,
          replacedByTokenHash: targetHash,
        },
        {
          $set: {
            revoked: false,
            replacedByTokenHash: null,
          },
        }
      ).exec();

      if (result.modifiedCount === 0) {
        return false;
      }

      const postCheckExists = await RefreshTokenModel.exists({
        tokenHash: targetHash,
      }).exec();

      if (postCheckExists) {
        await RefreshTokenModel.updateOne(
          {
            tokenHash,
            revoked: false,
          },
          {
            $set: {
              revoked: true,
              replacedByTokenHash: targetHash,
            },
          }
        ).exec();
        return false;
      }

      return true;
    }

    const result = await RefreshTokenModel.updateOne(
      { tokenHash, revoked: true },
      { $set: { revoked: false, replacedByTokenHash: null } }
    ).exec();
    return result.modifiedCount > 0;
  }

  async revokeRefreshToken(token: string): Promise<boolean> {
    if (mongoose.connection.readyState !== 1) {
      throw new ServiceUnavailableError('Authentication service unavailable: database disconnected');
    }
    const tokenHash = hashToken(token);
    const result = await RefreshTokenModel.updateOne(
      { tokenHash, revoked: false },
      { $set: { revoked: true } }
    ).exec();
    return result.modifiedCount > 0;
  }

  async revokeTokenFamily(tokenFamily: string): Promise<number> {
    if (mongoose.connection.readyState !== 1) {
      throw new ServiceUnavailableError('Authentication service unavailable: database disconnected');
    }
    const result = await RefreshTokenModel.updateMany(
      { tokenFamily, revoked: false },
      { $set: { revoked: true } }
    ).exec();
    return result.modifiedCount;
  }

  async revokeAllUserRefreshTokens(userId: string): Promise<number> {
    if (mongoose.connection.readyState !== 1) {
      throw new ServiceUnavailableError('Authentication service unavailable: database disconnected');
    }
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return 0;
    }
    const result = await RefreshTokenModel.updateMany(
      { userId: new mongoose.Types.ObjectId(userId), revoked: false },
      { $set: { revoked: true } }
    ).exec();
    return result.modifiedCount;
  }

  async incrementTokenVersion(userId: string): Promise<number> {
    if (mongoose.connection.readyState !== 1) {
      return 1;
    }
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return 0;
    }
    const result = await UserModel.findByIdAndUpdate(
      userId,
      { $inc: { tokenVersion: 1 } },
      { new: true }
    ).exec();
    return result?.tokenVersion ?? 1;
  }

  async setPasswordResetToken(
    userId: string,
    tokenHash: string,
    expiresAt: Date
  ): Promise<void> {
    if (mongoose.connection.readyState !== 1) {
      return;
    }
    await UserModel.findByIdAndUpdate(userId, {
      $set: {
        passwordResetTokenHash: tokenHash,
        passwordResetExpiresAt: expiresAt,
      },
    }).exec();
  }

  async findByPasswordResetToken(tokenHash: string): Promise<IUser | null> {
    if (mongoose.connection.readyState !== 1) {
      return null;
    }
    return await UserModel.findOne({
      passwordResetTokenHash: tokenHash,
      passwordResetExpiresAt: { $gt: new Date() },
    })
      .select('+passwordHash +passwordResetTokenHash +passwordResetExpiresAt')
      .exec();
  }

  async resetPassword(
    userId: string,
    newPasswordHash: string
  ): Promise<void> {
    if (mongoose.connection.readyState !== 1) {
      throw new ServiceUnavailableError('Authentication service unavailable: database disconnected');
    }
    await UserModel.findByIdAndUpdate(userId, {
      $set: {
        passwordHash: newPasswordHash,
        passwordResetTokenHash: null,
        passwordResetExpiresAt: null,
      },
      $inc: { tokenVersion: 1 },
    }).exec();
  }

  async setEmailVerificationToken(
    userId: string,
    tokenHash: string,
    expiresAt: Date
  ): Promise<void> {
    if (mongoose.connection.readyState !== 1) {
      return;
    }
    if (!mongoose.Types.ObjectId.isValid(userId)) {
      return;
    }
    await UserModel.findByIdAndUpdate(userId, {
      $set: {
        emailVerificationTokenHash: tokenHash,
        emailVerificationExpiresAt: expiresAt,
      },
    }).exec();
  }

  async findByEmailVerificationToken(tokenHash: string): Promise<IUser | null> {
    if (mongoose.connection.readyState !== 1) {
      return null;
    }
    return await UserModel.findOne({
      emailVerificationTokenHash: tokenHash,
      emailVerificationExpiresAt: { $gt: new Date() },
    })
      .select('+emailVerificationTokenHash +emailVerificationExpiresAt')
      .exec();
  }

  async markEmailVerified(userId: string): Promise<void> {
    if (mongoose.connection.readyState !== 1) {
      throw new ServiceUnavailableError('Authentication service unavailable: database disconnected');
    }
    const result = await UserModel.findByIdAndUpdate(userId, {
      $set: {
        isEmailVerified: true,
        emailVerificationTokenHash: null,
        emailVerificationExpiresAt: null,
      },
    }).exec();
    if (!result) {
      throw new NotFoundError('User');
    }
  }
}

export const authRepository = new AuthRepository();
