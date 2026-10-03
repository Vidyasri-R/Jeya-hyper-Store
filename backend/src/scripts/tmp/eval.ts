import { closeDb } from '../../db/client';
import { usageService } from '../../modules/usage/usage.service';
const t0 = Date.now();
const w = setInterval(() => console.log(`… still running ${Math.round((Date.now() - t0) / 1000)}s`), 15_000);
usageService.evaluate().then((r) => console.log('evaluate ok', r, `${Date.now() - t0} ms`)).catch((e) => console.log('evaluate threw', e?.message ?? e)).finally(async () => { clearInterval(w); await closeDb(); });
