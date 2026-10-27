import 'user.dart';

class LoginRequest {
  final String email;
  final String password;

  const LoginRequest({required this.email, required this.password});

  Map<String, dynamic> toJson() => {
        'email': email.trim().toLowerCase(),
        'password': password,
      };
}

class RegisterRequest {
  final String displayName;
  final String email;
  final String password;

  const RegisterRequest({
    required this.displayName,
    required this.email,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'displayName': displayName.trim(),
        'email': email.trim().toLowerCase(),
        'password': password,
      };
}

class RefreshTokenRequest {
  final String refreshToken;

  const RefreshTokenRequest({required this.refreshToken});

  Map<String, dynamic> toJson() => {
        'refreshToken': refreshToken,
      };
}

class RegisterResponse {
  final String message;

  const RegisterResponse({required this.message});

  factory RegisterResponse.fromJson(Map<String, dynamic> json) =>
      RegisterResponse(message: json['message'] as String? ?? 'Registration successful');
}

class ResendVerificationRequest {
  final String email;

  const ResendVerificationRequest({required this.email});

  Map<String, dynamic> toJson() => {
        'email': email.trim().toLowerCase(),
      };
}

class VerifyEmailRequest {
  final String token;

  const VerifyEmailRequest({required this.token});

  Map<String, dynamic> toJson() {
    var cleanToken = token.trim().replaceAll(RegExp(r'''^["']|["']$'''), '').trim();

    // 1. If input contains a 64-hex token (e.g. raw, copied with console label, or in URL), extract it
    final hexMatch = RegExp(r'\b([0-9a-fA-F]{64})\b').firstMatch(cleanToken);
    if (hexMatch != null && hexMatch.group(1) != null) {
      return {
        'token': hexMatch.group(1)!.toLowerCase(),
      };
    }

    // 2. Otherwise extract token query parameter from URLs, hash fragments, or query strings
    if (cleanToken.contains('token=')) {
      final uri = Uri.tryParse(cleanToken);
      if (uri != null) {
        if (uri.queryParameters.containsKey('token')) {
          final t = uri.queryParameters['token'];
          if (t != null && t.trim().isNotEmpty) {
            cleanToken = t.trim();
          }
        } else if (uri.hasFragment && uri.fragment.contains('token=')) {
          final fragmentQueryIndex = uri.fragment.indexOf('?');
          final fragmentQuery = fragmentQueryIndex != -1
              ? uri.fragment.substring(fragmentQueryIndex + 1)
              : uri.fragment;
          final fragmentParams = Uri.splitQueryString(fragmentQuery);
          final t = fragmentParams['token'];
          if (t != null && t.trim().isNotEmpty) {
            cleanToken = t.trim();
          }
        }
      }

      if (cleanToken.contains('token=')) {
        final match = RegExp(r'(?:[?&]|#.*[?&]|^)token=([^&#\s]+)').firstMatch(cleanToken);
        if (match != null && match.group(1) != null) {
          final candidate = match.group(1)!.trim().replaceAll(RegExp(r'''^["']|["']$'''), '');
          try {
            cleanToken = Uri.decodeComponent(candidate);
          } catch (_) {
            cleanToken = candidate;
          }
        }
      }
    }
    cleanToken = cleanToken.replaceAll(RegExp(r'''^["']|["']$'''), '').trim();
    return {
      'token': cleanToken,
    };
  }
}

class RequestPasswordResetRequest {
  final String email;

  const RequestPasswordResetRequest({required this.email});

  Map<String, dynamic> toJson() => {
        'email': email.trim().toLowerCase(),
      };
}

class ResetPasswordConfirmRequest {
  final String token;
  final String newPassword;

  const ResetPasswordConfirmRequest({
    required this.token,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
        'token': token.trim(),
        'newPassword': newPassword,
      };
}

class MessageResponse {
  final String message;

  const MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) =>
      MessageResponse(message: json['message'] as String? ?? '');
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );
}
