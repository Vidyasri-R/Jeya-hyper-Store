import type { StaffRole, UserRole } from '../db/schema';

declare global {
  namespace Express {
    interface Request {
      /** Set by requireAuth after a valid access token. */
      auth?: {
        userId: string;
        role: UserRole;
        sessionId: string;
      };
      /** Set by requireStaff (Jeya Staff app). */
      staff?: {
        staffId: string;
        role: StaffRole;
        sessionId: string;
      };
    }
  }
}

export {};
