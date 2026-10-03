/**
 * In-process "something about orders changed" counter. The staff order board polls a tiny
 * summary endpoint; while this number is unchanged the summary is served from memory, so
 * polling costs no database round trip (Supabase egress and Render bandwidth are metered).
 * Every order mutation runs in this process (single Render instance), and the summary also
 * expires after a minute as a safety net.
 */
let version = 0;

export const orderEvents = {
  bump(): void {
    version++;
  },
  version(): number {
    return version;
  },
};
