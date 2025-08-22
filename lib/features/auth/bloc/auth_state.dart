import 'package:shopify_flutter/shopify_flutter.dart';

/// Authentication state enum
enum AuthStatus {
  /// User is authenticated
  authenticated,
  
  /// User is not authenticated
  unauthenticated,
  
  /// Authentication status is being determined
  loading,
  
  /// Authentication error occurred
  error
}

/// Class to represent the current authentication state
class AuthState {
  /// Current authentication status
  final AuthStatus status;
  
  /// Current user if authenticated
  final ShopifyUser? user;
  
  /// Error message if status is error
  final String? errorMessage;
  
  /// Error code if status is error
  final String? errorCode;

  /// Constructor
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
    this.errorCode,
  });

  /// Initial state - loading
  factory AuthState.initial() => const AuthState(status: AuthStatus.loading);

  /// Authenticated state
  factory AuthState.authenticated(ShopifyUser user) => AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );

  /// Unauthenticated state
  factory AuthState.unauthenticated() => const AuthState(
        status: AuthStatus.unauthenticated,
      );

  /// Error state
  factory AuthState.error(String message, {String? code}) => AuthState(
        status: AuthStatus.error,
        errorMessage: message,
        errorCode: code,
      );

  /// Copy with method to create a new instance with updated values
  AuthState copyWith({
    AuthStatus? status,
    ShopifyUser? user,
    String? errorMessage,
    String? errorCode,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage ?? this.errorMessage,
      errorCode: errorCode ?? this.errorCode,
    );
  }

  /// Check if user is authenticated
  bool get isAuthenticated => status == AuthStatus.authenticated && user != null;

  /// Check if authentication is in progress
  bool get isLoading => status == AuthStatus.loading;

  /// Check if there's an authentication error
  bool get hasError => status == AuthStatus.error;
}