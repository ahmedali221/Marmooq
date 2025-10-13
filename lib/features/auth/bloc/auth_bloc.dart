import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:marmooq/core/services/auth_exception.dart';
import 'package:marmooq/features/auth/bloc/auth_state.dart';
import 'package:marmooq/core/services/shopify_auth_service.dart';

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
  final String firstName;
  final String lastName;
  final String phone;
  final bool? acceptsMarketing;

  AuthRegister({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.phone,
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

/// Event to update profile fields
class AuthUpdateProfile extends AuthEvent {
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? email;
  final bool? acceptsMarketing;

  AuthUpdateProfile({
    this.firstName,
    this.lastName,
    this.phone,
    this.email,
    this.acceptsMarketing,
  });

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    phone,
    email,
    acceptsMarketing,
  ];
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
    on<AuthDeleteAccount>(_onDeleteAccount);
    on<AuthUpdateProfile>(_onUpdateProfile);
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

      // If sign in succeeds, user is authenticated (token is stored)
      emit(AuthState.authenticated(user));
    } on AuthException catch (e) {
      emit(AuthState.error(e.message, code: e.code));
    } catch (e) {
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
        phone:
            event.phone, // Phone already has +965 prefix from register screen
        acceptsMarketing: event.acceptsMarketing,
      );

      // If registration succeeds, user is authenticated (token is stored)
      emit(AuthState.authenticated(user));
    } on AuthException catch (e) {
      emit(AuthState.error(e.message, code: e.code));
    } catch (e) {
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

  /// Update profile fields
  Future<void> _onUpdateProfile(
    AuthUpdateProfile event,
    Emitter<AuthState> emit,
  ) async {
    emit(state.copyWith(status: AuthStatus.loading));
    try {
      final updated = await _authService.updateCustomer(
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
        email: event.email,
        acceptsMarketing: event.acceptsMarketing,
      );
      emit(AuthState.authenticated(updated));
    } on AuthException catch (e) {
      emit(AuthState.error(e.message, code: e.code));
    } catch (e) {
      emit(AuthState.error('An error occurred while updating profile'));
    }
  }
}
