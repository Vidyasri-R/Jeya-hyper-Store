import { AppError } from '../../common/errors';
import { logger } from '../../config/logger';
import { db } from '../../db/client';
import { authRepository } from '../auth/auth.repository';
import { toPublicUser, type PublicUser } from '../auth/auth.service';
import type { UpdateProfileInput } from './users.schemas';
import { usersRepository } from './users.repository';

export const usersService = {
  async getMe(userId: string): Promise<PublicUser> {
    const user = await usersRepository.findActiveById(db, userId);
    if (!user) throw new AppError('UNAUTHORIZED', 'Account not found', { reason: 'account_missing' });
    return toPublicUser(user);
  },

  async updateMe(userId: string, input: UpdateProfileInput): Promise<PublicUser> {
    const user = await usersRepository.updateProfile(db, userId, input);
    if (!user) throw new AppError('UNAUTHORIZED', 'Account not found', { reason: 'account_missing' });
    return toPublicUser(user);
  },

  /** Apple 5.1.1(v) / Google Play account-deletion requirement. */
  async deleteMe(userId: string): Promise<void> {
    await db.transaction(async (tx) => {
      const user = await usersRepository.findActiveById(tx, userId);
      if (!user) throw new AppError('UNAUTHORIZED', 'Account not found', { reason: 'account_missing' });

      const inFlight = await usersRepository.countInFlightOrders(tx, userId);
      if (inFlight > 0) {
        throw new AppError(
          'CONFLICT',
          'You have orders still being delivered. Please delete your account after they are completed.',
          { reason: 'orders_in_flight', inFlightOrders: inFlight },
        );
      }

      await usersRepository.softDeleteAndScrub(tx, userId);
      await authRepository.revokeAllSessionsForUser(tx, userId);
    });
    logger.info({ userId }, 'account deleted');
  },
};
