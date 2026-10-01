import { env } from '../../config/env';
import { MockGoFrugalClient } from './mock-client';
import type { PosCatalogClient } from './types';

/**
 * Single switch point for the POS integration. When GoFrugal API credentials
 * arrive, add an HTTP client implementing PosCatalogClient (with its field
 * mapping isolated there) and a 'gofrugal' case here — the sync engine,
 * validation and DB upserts don't change.
 */
function createPosClient(): PosCatalogClient {
  switch (env.POS_PROVIDER) {
    case 'mock':
      return new MockGoFrugalClient();
  }
}

export const posClient: PosCatalogClient = createPosClient();
export type { PosCatalogClient } from './types';
