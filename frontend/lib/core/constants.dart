import 'package:flutter/foundation.dart';

class AppConstants {
  AppConstants._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001',
  );

  static String get baseUrl => sanitizeApiUrl(_configuredBaseUrl);

  static String sanitizeApiUrl(String url, {bool? isRelease}) {
    final trimmed = url.trim();
    final checkRelease = isRelease ?? kReleaseMode;
    if (checkRelease) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null || uri.scheme.toLowerCase() != 'https') {
        throw StateError(
          'Insecure HTTP base URL is strictly prohibited in release builds: $trimmed. HTTPS is required.',
        );
      }
    }
    return trimmed;
  }

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int defaultPageSize = 20;

  static const String localeKey = 'app_locale';

  static const List<String> supportedLocales = ['en', 'hi'];
}

class ClaimStatus {
  ClaimStatus._();
  static const String draft = 'draft';
  static const String submitted = 'submitted';
  static const String underReview = 'under_review';
  static const String verified = 'verified';
  static const String partiallyVerified = 'partially_verified';
  static const String unverified = 'unverified';
  static const String disputed = 'disputed';
  static const String insufficientEvidence = 'insufficient_evidence';
  static const String rejected = 'rejected';
  static const String archived = 'archived';
}

class ClaimCategory {
  ClaimCategory._();
  static const String historicalRecord = 'HISTORICAL_RECORD';
  static const String currentFact = 'CURRENT_FACT';
  static const String folklore = 'FOLKLORE';
  static const String personalExperience = 'PERSONAL_EXPERIENCE';
  static const String publicOpinion = 'PUBLIC_OPINION';
  static const String surveyData = 'SURVEY_DATA';
  static const String disputedClaim = 'DISPUTED_CLAIM';
}

class PlaceLevel {
  PlaceLevel._();
  static const String country = 'COUNTRY';
  static const String state = 'STATE';
  static const String district = 'DISTRICT';
  static const String tehsil = 'TEHSIL';
  static const String cityTown = 'CITY_TOWN';
  static const String village = 'VILLAGE';
}
