import type { Request } from 'express';
import type { z } from 'zod';

/**
 * Parse and type a request part. Throws ZodError, which the error handler turns
 * into a 422 with field-level details.
 */
export function parseBody<T extends z.ZodType>(schema: T, req: Request): z.infer<T> {
  return schema.parse(req.body ?? {});
}

export function parseQuery<T extends z.ZodType>(schema: T, req: Request): z.infer<T> {
  return schema.parse(req.query);
}

export function parseParams<T extends z.ZodType>(schema: T, req: Request): z.infer<T> {
  return schema.parse(req.params);
}
