sealed class Failure {
  final String message;
  final String? code;
  const Failure({required this.message, this.code});
}

final class NetworkFailure extends Failure {
  const NetworkFailure({super.message = 'Network error', super.code = 'NETWORK_ERROR'});
}

final class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});
}

final class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code = 'UNAUTHENTICATED'});
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure({super.message = 'Not found', super.code = 'NOT_FOUND'});
}

final class ValidationFailure extends Failure {
  const ValidationFailure({required super.message, super.code = 'VALIDATION_ERROR'});
}

final class BusinessRuleFailure extends Failure {
  const BusinessRuleFailure({required super.message, super.code = 'BUSINESS_RULE_VIOLATION'});
}

final class ConflictFailure extends Failure {
  const ConflictFailure({required super.message, super.code = 'CONFLICT'});
}

final class UnknownFailure extends Failure {
  const UnknownFailure({super.message = 'An unknown error occurred', super.code = 'UNKNOWN'});
}
