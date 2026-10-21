import {
  AppError,
  ValidationError,
  AuthenticationError,
  AuthorizationError,
  SelfReviewError,
  NotFoundError,
  ConflictError,
  BusinessRuleError,
  ServiceUnavailableError,
} from '../../../src/shared/errors/AppError';

describe('AppError classes', () => {
  it('ValidationError has status 400 and correct code', () => {
    const err = new ValidationError('Bad input');
    expect(err.statusCode).toBe(400);
    expect(err.code).toBe('VALIDATION_ERROR');
    expect(err.message).toBe('Bad input');
    expect(err.isOperational).toBe(true);
  });

  it('AuthenticationError has status 401', () => {
    const err = new AuthenticationError();
    expect(err.statusCode).toBe(401);
    expect(err.code).toBe('UNAUTHENTICATED');
  });

  it('AuthorizationError has status 403', () => {
    const err = new AuthorizationError();
    expect(err.statusCode).toBe(403);
    expect(err.code).toBe('UNAUTHORIZED');
  });

  it('SelfReviewError has status 403 and SELF_REVIEW_PROHIBITED code', () => {
    const err = new SelfReviewError();
    expect(err.statusCode).toBe(403);
    expect(err.code).toBe('SELF_REVIEW_PROHIBITED');
  });

  it('NotFoundError has status 404', () => {
    const err = new NotFoundError('Claim');
    expect(err.statusCode).toBe(404);
    expect(err.message).toBe('Claim not found');
  });

  it('ConflictError has status 409', () => {
    const err = new ConflictError('Already exists');
    expect(err.statusCode).toBe(409);
  });

  it('BusinessRuleError has status 422', () => {
    const err = new BusinessRuleError('Cannot self-approve');
    expect(err.statusCode).toBe(422);
    expect(err.code).toBe('BUSINESS_RULE_VIOLATION');
  });

  it('ServiceUnavailableError has status 503 and SERVICE_UNAVAILABLE code', () => {
    const err = new ServiceUnavailableError('Database down');
    expect(err.statusCode).toBe(503);
    expect(err.code).toBe('SERVICE_UNAVAILABLE');
    expect(err.message).toBe('Database down');
  });

  it('All errors are instances of AppError and Error', () => {
    const errors = [
      new ValidationError('x'),
      new AuthenticationError(),
      new AuthorizationError(),
      new SelfReviewError(),
      new NotFoundError('X'),
      new ConflictError('x'),
      new BusinessRuleError('x'),
      new ServiceUnavailableError('x'),
    ];
    errors.forEach(err => {
      expect(err).toBeInstanceOf(AppError);
      expect(err).toBeInstanceOf(Error);
    });
  });
});
