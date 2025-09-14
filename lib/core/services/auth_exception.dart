/// Custom exception class for authentication errors
class AuthException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AuthException(this.message, {this.code, this.originalError});

  @override
  String toString() =>
      'AuthException: $message${code != null ? ' (Code: $code)' : ''}';

  /// Factory constructor for common authentication errors
  factory AuthException.fromShopifyError(dynamic error) {
    String message = 'An unknown authentication error occurred';
    String? code;

    if (error is String) {
      message = error;
    } else if (error is Map) {
      if (error.containsKey('message')) {
        message = error['message'];
      }
      if (error.containsKey('code')) {
        code = error['code'];
      }
    }

    // Handle common Shopify error messages
    if (message.contains('Unidentified customer')) {
      return AuthException(
        'Invalid email or password',
        code: 'invalid_credentials',
        originalError: error,
      );
    } else if (message.contains('password')) {
      return AuthException(
        'Password is incorrect',
        code: 'invalid_password',
        originalError: error,
      );
    } else if (message.contains('email') && message.contains('taken')) {
      return AuthException(
        'Email is already in use',
        code: 'email_in_use',
        originalError: error,
      );
    } else if (message.contains('token') && message.contains('expired')) {
      return AuthException(
        'Your session has expired. Please sign in again',
        code: 'token_expired',
        originalError: error,
      );
    }

    return AuthException(message, code: code, originalError: error);
  }

  /// Common error types
  static AuthException invalidCredentials() {
    return AuthException(
      'Invalid email or password',
      code: 'invalid_credentials',
    );
  }

  static AuthException emailInUse() {
    return AuthException('Email is already in use', code: 'email_in_use');
  }

  static AuthException weakPassword() {
    return AuthException('Password is too weak', code: 'weak_password');
  }

  static AuthException networkError() {
    return AuthException(
      'Network error. Please check your connection',
      code: 'network_error',
    );
  }

  static AuthException serverError() {
    return AuthException(
      'Server error. Please try again later',
      code: 'server_error',
    );
  }

  static AuthException userNotFound() {
    return AuthException('User not found', code: 'user_not_found');
  }

  static AuthException sessionExpired() {
    return AuthException(
      'Your session has expired. Please sign in again',
      code: 'session_expired',
    );
  }
}
