import { AppError } from '../../common/errors';
import { db } from '../../db/client';
import type { Address } from '../../db/schema';
import { deliveryService } from '../delivery/delivery.service';
import { addressesRepository } from './addresses.repository';
import type { CreateAddressInput, UpdateAddressInput } from './addresses.schemas';

const MAX_ADDRESSES = 10;

export type PublicAddress = {
  id: string;
  label: string | null;
  recipientName: string;
  phone: string;
  pincode: string;
  line1: string;
  line2: string | null;
  landmark: string | null;
  city: string;
  state: string;
  latitude: string | null;
  longitude: string | null;
  isDefault: boolean;
  /** False → show "We don't deliver here yet" and block checkout with this address. */
  serviceable: boolean;
};

function toPublic(address: Address, serviceable: boolean): PublicAddress {
  return {
    id: address.id,
    label: address.label,
    recipientName: address.recipientName,
    phone: address.phone,
    pincode: address.pincode,
    line1: address.line1,
    line2: address.line2,
    landmark: address.landmark,
    city: address.city,
    state: address.state,
    latitude: address.latitude,
    longitude: address.longitude,
    isDefault: address.isDefault,
    serviceable,
  };
}

async function withServiceability(rows: Address[]): Promise<PublicAddress[]> {
  const serviceable = await deliveryService.serviceability(rows);
  return rows.map((row, i) => toPublic(row, serviceable[i] ?? false));
}

export const addressesService = {
  async list(userId: string): Promise<PublicAddress[]> {
    return withServiceability(await addressesRepository.listForUser(db, userId));
  },

  async create(userId: string, input: CreateAddressInput): Promise<PublicAddress> {
    const created = await db.transaction(async (tx) => {
      await addressesRepository.lockUserAddresses(tx, userId);
      const count = await addressesRepository.countForUser(tx, userId);
      if (count >= MAX_ADDRESSES) {
        throw new AppError('CONFLICT', `You can save up to ${MAX_ADDRESSES} addresses. Delete one to add another.`, {
          reason: 'address_limit',
        });
      }
      // First address is always the default.
      const isDefault = input.isDefault || count === 0;
      if (isDefault) await addressesRepository.clearDefault(tx, userId);
      return addressesRepository.insert(tx, { ...input, userId, isDefault });
    });
    const [result] = await withServiceability([created]);
    return result!;
  },

  async update(userId: string, id: string, input: UpdateAddressInput): Promise<PublicAddress> {
    const updated = await db.transaction(async (tx) => {
      await addressesRepository.lockUserAddresses(tx, userId);
      if (input.isDefault) await addressesRepository.clearDefault(tx, userId, id);
      const row = await addressesRepository.update(tx, userId, id, input);
      if (!row) throw AppError.notFound('Address');
      return row;
    });
    const [result] = await withServiceability([updated]);
    return result!;
  },

  async remove(userId: string, id: string): Promise<void> {
    await db.transaction(async (tx) => {
      await addressesRepository.lockUserAddresses(tx, userId);
      const existing = await addressesRepository.findForUser(tx, userId, id);
      if (!existing) throw AppError.notFound('Address');
      await addressesRepository.softDelete(tx, userId, id);
      // Past orders keep their own address snapshot, so deleting is always safe.
      if (existing.isDefault) {
        const next = await addressesRepository.mostRecent(tx, userId);
        if (next) await addressesRepository.update(tx, userId, next.id, { isDefault: true });
      }
    });
  },
};
