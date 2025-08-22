import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:traincode/core/services/auth_exception.dart';
import 'package:traincode/features/auth/bloc/auth_state.dart';
import 'package:traincode/core/services/shopify_auth_service.dart';

/// Authentication events
abstract class AuthEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

/// Event to initialize authentication state
class AuthInitialize extends AuthEvent {}

/// Event to sign in with email and password
class AuthSignIn extends AuthEvent {
  final String email;
  final String password;

  AuthSignIn({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Event to register a new user
class AuthRegister extends AuthEvent {
  final String email;
  final String password;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final bool? acceptsMarketing;

  AuthRegister({
    required this.email,
    required this.password,
    this.firstName,
    this.lastName,
    this.phone,
    this.acceptsMarketing,
  });

  @override
  List<Object?> get props => [
    email,
    password,
    firstName,
    lastName,
    phone,
    acceptsMarketing,
  ];
}

/// Event to sign out
class AuthSignOut extends AuthEvent {}

/// Event to reset password
class AuthResetPassword extends AuthEvent {
  final String email;

  AuthResetPassword({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Event to delete account
class AuthDeleteAccount extends AuthEvent {
  final String userId;

  AuthDeleteAccount({required this.userId});

  @override
  List<Object?> get props => [userId];
}

/// Authentication BLoC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final ShopifyAuthService _authService;

  AuthBloc({ShopifyAuthService? authService})
    : _authService = authService ?? ShopifyAuthService.instance,
      super(AuthState.initial()) {
    on<AuthInitialize>(_onInitialize);
    on<AuthSignIn>(_onSignIn);
    on<AuthRegister>(_onRegister);
    on<AuthSignOut>(_onSignOut);
    on<AuthResetPassword>(_onResetPassword);
    on<AuthDeleteAccount>(_onDeleteAccount);
  }

  /// Initialize authentication state
  Future<void> _onInitialize(
    AuthInitialize event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      // Check if user is already authenticated
      final isAuthenticated = await _authService.isAuthenticated();
      if (isAuthenticated) {
        final user = await _authService.currentUser();
        if (user != null) {
          emit(AuthState.authenticated(user));
        } else {
          emit(AuthState.unauthenticated());
        }
      } else {
        emit(AuthState.unauthenticated());
      }
    } catch (e) {
      debugPrint('Auth initialization error: $e');
      emit(AuthState.unauthenticated());
    }
  }

  /// Sign in with email and password
  Future<void> _onSignIn(AuthSignIn event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email: event.email,
        password: event.password,
      );
      
      // Verify authentication was successful
      final isAuthenticated = await _authService.isAuthenticated();
      if (isAuthenticated) {
        emit(AuthState.authenticated(user));
      } else {
        emit(AuthState.error('Authentication verification failed'));
      }
    } on AuthException catch (e) {
      emit(AuthState.error(e.message, code: e.code));
    } catch (e) {
      debugPrint('Sign in error: $e');
      emit(AuthState.error('An unexpected error occurred during sign in'));
    }
  }

  /// Register a new user
  Future<void> _onRegister(AuthRegister event, Emitter<AuthState> emit) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final user = await _authService.createUserWithEmailAndPassword(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
        acceptsMarketing: event.acceptsMarketing,
      );
      
      // Verify authentication was successful
      final isAuthenticated = await _authService.isAuthenticated();
      if (isAuthenticated) {
        emit(AuthState.authenticated(user));
      } else {
        emit(AuthState.error('Registration verification failed'));
      }
    } on AuthException catch (e) {
      emit(AuthState.error(e.message, code: e.code));
    } catch (e) {
      debugPrint('Registration error: $e');
      emit(AuthState.error('An unexpected error occurred during registration'));
    }
  }

  /// Sign out
  Future<void> _onSignOut(AuthSignOut event, Emitter<AuthState> emit) async {
    try {
      await _authService.signOutCurrentUser();
      emit(AuthState.unauthenticated());
    } catch (e) {
      emit(AuthState.error('An error occurred during sign out'));
    }
  }

  /// Reset password
  Future<void> _onResetPassword(
    AuthResetPassword event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.sendPasswordResetEmail(email: event.email);
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: null,
          errorCode: null,
        ),
      );
    } on AuthException catch (e) {
      emit(AuthState.error(e.message, code: e.code));
    } catch (e) {
      emit(
        AuthState.error('An error occurred while sending password reset email'),
      );
    }
  }

  /// Delete account
  Future<void> _onDeleteAccount(
    AuthDeleteAccount event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authService.deleteCustomer(userId: event.userId);
      emit(AuthState.unauthenticated());
    } on AuthException catch (e) {
      emit(AuthState.error(e.message, code: e.code));
    } catch (e) {
      emit(AuthState.error('An error occurred while deleting account'));
    }
  }
}
