import type { ErrorRequestHandler, RequestHandler } from 'express';
import { ZodError } from 'zod';
import { isProduction } from '../config/env';
import { AppError, PG_ERROR, pgErrorCode } from './errors';

export const notFoundHandler: RequestHandler = (req, _res, next) => {
  next(new AppError('NOT_FOUND', `Route ${req.method} ${req.path} not found`));
};

function toAppError(error: unknown): AppError {
  if (error instanceof AppError) return error;

  if (error instanceof ZodError) {
    return new AppError(
      'VALIDATION_FAILED',
      'Request validation failed',
      error.issues.map((issue) => ({ path: issue.path.join('.'), message: issue.message })),
    );
  }

  // express.json() body parse failures
  if (typeof error === 'object' && error !== null && 'type' in error) {
    if (error.type === 'entity.parse.failed') return new AppError('BAD_REQUEST', 'Malformed JSON body');
    if (error.type === 'entity.too.large') return new AppError('BAD_REQUEST', 'Request body too large');
  }

  switch (pgErrorCode(error)) {
    case PG_ERROR.UNIQUE_VIOLATION:
      return new AppError('CONFLICT', 'Resource already exists');
    case PG_ERROR.FOREIGN_KEY_VIOLATION:
      return new AppError('CONFLICT', 'Referenced resource does not exist or is in use');
    case PG_ERROR.CHECK_VIOLATION:
    case PG_ERROR.NOT_NULL_VIOLATION:
      return new AppError('BAD_REQUEST', 'Invalid data');
    case PG_ERROR.SERIALIZATION_FAILURE:
    case PG_ERROR.DEADLOCK_DETECTED:
      return new AppError('CONFLICT', 'Concurrent update, please retry');
    case PG_ERROR.QUERY_CANCELED:
      return new AppError('UPSTREAM_UNAVAILABLE', 'Database timeout, please retry');
    default:
      return new AppError('INTERNAL', 'Something went wrong');
  }
}

export const errorHandler: ErrorRequestHandler = (error, req, res, _next) => {
  const appError = toAppError(error);

  if (appError.status >= 500) {
    req.log.error({ err: error }, 'request failed');
  } else {
    req.log.warn({ code: appError.code, msg: appError.message }, 'request rejected');
  }

  if (res.headersSent) return;

  res.status(appError.status).json({
    error: {
      code: appError.code,
      message: appError.message,
      ...(appError.details !== undefined ? { details: appError.details } : {}),
      requestId: req.id,
      ...(!isProduction && appError.status >= 500 && error instanceof Error ? { debug: error.message } : {}),
    },
  });
};
