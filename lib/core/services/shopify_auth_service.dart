import 'package:flutter/foundation.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/core/services/security_service.dart';
import 'package:traincode/core/services/auth_exception.dart';

/// Service for handling Shopify authentication operations.
class ShopifyAuthService {
  final ShopifyAuth _shopifyAuth = ShopifyAuth.instance;

  /// Singleton instance
  static final ShopifyAuthService _instance = ShopifyAuthService._internal();

  /// Private constructor
  ShopifyAuthService._internal();

  /// Factory constructor to return the singleton instance
  factory ShopifyAuthService() => _instance;

  /// Static getter for the singleton instance
  static ShopifyAuthService get instance => _instance;

  /// Sign in with email and password
  /// Returns the ShopifyUser on success
  /// Throws an AuthException on failure
  Future<ShopifyUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _shopifyAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Store the access token securely
      final accessToken = await _shopifyAuth.currentCustomerAccessToken;
      if (accessToken != null) {
        await SecurityService.storeAccessToken(accessToken);

        // Store token expiration date if available
        final tokenWithExpDate = await _shopifyAuth.accessTokenWithExpDate;
        if (tokenWithExpDate?.expiresAt != null) {
          await SecurityService.storeTokenExpirationDate(
            tokenWithExpDate!.expiresAt!,
          );
        } else {
          // Set default expiration to 24 hours if not provided
          final defaultExpiration = DateTime.now().add(
            const Duration(hours: 24),
          );
          await SecurityService.storeTokenExpirationDate(defaultExpiration);
        }
      }

      // Store user data securely
      if (user != null) {
        final userData = <String, dynamic>{
          'email': user.email,
          'firstName': user.firstName,
          'lastName': user.lastName,
          'phone': user.phone,
          'id': user.id,
        };
        await SecurityService.syncUserDataWithShopify(userData);
      }

      // Generate a new session ID for this login
      await SecurityService.generateSessionId();

      return user;
    } catch (e) {
      debugPrint('Shopify sign in error: $e');
      throw AuthException.fromShopifyError(e);
    }
  }

  /// Create a new user account with email and password
  /// Optional fields: phone, firstName, lastName, acceptsMarketing
  /// Returns the ShopifyUser on success
  /// Throws an AuthException on failure
  Future<ShopifyUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? phone,
    String? firstName,
    String? lastName,
    bool? acceptsMarketing,
  }) async {
    try {
      final user = await _shopifyAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update additional fields if provided
      if (firstName != null || lastName != null || phone != null || acceptsMarketing != null) {
        final customer = ShopifyCustomer.instance;
        await customer.customerUpdate(
          firstName: firstName,
          lastName: lastName,
          phoneNumber: phone,
          acceptsMarketing: acceptsMarketing,
        );
      }

      // Store the access token securely
      final accessToken = await _shopifyAuth.currentCustomerAccessToken;
      if (accessToken != null) {
        await SecurityService.storeAccessToken(accessToken);

        // Store token expiration date if available
        final tokenWithExpDate = await _shopifyAuth.accessTokenWithExpDate;
        if (tokenWithExpDate?.expiresAt != null) {
          await SecurityService.storeTokenExpirationDate(
            tokenWithExpDate!.expiresAt!,
          );
        } else {
          // Set default expiration to 24 hours if not provided
          final defaultExpiration = DateTime.now().add(
            const Duration(hours: 24),
          );
          await SecurityService.storeTokenExpirationDate(defaultExpiration);
        }
      }

      // Store user data securely
      if (user != null) {
        final userData = <String, dynamic>{
          'email': user.email,
          'firstName': user.firstName ?? firstName,
          'lastName': user.lastName ?? lastName,
          'phone': user.phone ?? phone,
          'id': user.id,
        };
        await SecurityService.syncUserDataWithShopify(userData);
      }

      // Generate a new session ID for this registration
      await SecurityService.generateSessionId();

      return user;
    } catch (e) {
      debugPrint('Shopify user creation error: $e');
      throw AuthException.fromShopifyError(e);
    }
  }

  /// Sign out the current user
  /// Clears all authentication data
  Future<void> signOutCurrentUser() async {
    try {
      await _shopifyAuth.signOutCurrentUser();
      await SecurityService.clearAllAuthData();
    } catch (e) {
      debugPrint('Shopify sign out error: $e');
      throw AuthException.fromShopifyError(e);
    }
  }

  /// Send a password reset email to the specified email address
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _shopifyAuth.sendPasswordResetEmail(email: email);
    } catch (e) {
      debugPrint('Shopify password reset error: $e');
      throw AuthException.fromShopifyError(e);
    }
  }

  /// Delete the customer account
  /// Requires the user ID
  Future<void> deleteCustomer({required String userId}) async {
    try {
      await _shopifyAuth.deleteCustomer(userId: userId);
      await SecurityService.clearAllAuthData();
    } catch (e) {
      debugPrint('Shopify delete customer error: $e');
      throw AuthException.fromShopifyError(e);
    }
  }

  /// Get the current user
  /// Set forceRefresh to true to bypass cache
  Future<ShopifyUser?> currentUser({bool forceRefresh = false}) async {
    try {
      return await _shopifyAuth.currentUser(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('Shopify get current user error: $e');
      return null;
    }
  }

  /// Get the current customer access token
  Future<String?> get currentCustomerAccessToken async {
    try {
      return await _shopifyAuth.currentCustomerAccessToken;
    } catch (e) {
      debugPrint('Shopify get access token error: $e');
      return null;
    }
  }

  /// Check if the access token is expired
  Future<bool> get isAccessTokenExpired async {
    try {
      return await _shopifyAuth.isAccessTokenExpired;
    } catch (e) {
      debugPrint('Shopify check token expiration error: $e');
      return true; // Assume expired on error
    }
  }

  /// Get the access token with expiration date
  Future<AccessTokenWithExpDate?> get accessTokenWithExpDate async {
    try {
      return await _shopifyAuth.accessTokenWithExpDate;
    } catch (e) {
      debugPrint('Shopify get token with expiration error: $e');
      return null;
    }
  }

  /// Check if the user is currently authenticated
  Future<bool> isAuthenticated() async {
    try {
      // Check if we have stored credentials
      final storedToken = await SecurityService.getAccessToken();
      final sessionId = await SecurityService.getSessionId();

      if (storedToken == null || sessionId == null) {
        return false;
      }

      // Check if token is expired based on stored expiration date
      final isExpired = await SecurityService.isTokenExpired();
      if (isExpired) {
        // Token is expired, clear auth data
        await SecurityService.clearAllAuthData();
        return false;
      }

      // Verify with Shopify service
      final user = await currentUser();
      final currentToken = await currentCustomerAccessToken;

      // Double-check token validity
      if (currentToken == null || currentToken.isEmpty) {
        await SecurityService.clearAllAuthData();
        return false;
      }

      // Verify token format
      if (!SecurityService.isValidTokenFormat(currentToken)) {
        await SecurityService.clearAllAuthData();
        return false;
      }

      return user != null;
    } catch (e) {
      debugPrint('Authentication check error: $e');
      // Clear potentially corrupted auth data
      await SecurityService.clearAllAuthData();
      return false;
    }
  }

  /// Get user display name for UI
  Future<String> getUserDisplayName() async {
    try {
      final userData = await SecurityService.getUserData();
      if (userData != null) {
        final firstName = userData['firstName'] as String?;
        final lastName = userData['lastName'] as String?;
        final email = userData['email'] as String?;

        if (firstName != null && firstName.isNotEmpty) {
          if (lastName != null && lastName.isNotEmpty) {
            return '$firstName $lastName';
          }
          return firstName;
        }

        if (email != null && email.isNotEmpty) {
          return email.split('@').first;
        }
      }

      // Fallback to current user from Shopify
      final user = await currentUser();
      if (user != null) {
        if (user.firstName != null && user.firstName!.isNotEmpty) {
          if (user.lastName != null && user.lastName!.isNotEmpty) {
            return '${user.firstName} ${user.lastName}';
          }
          return user.firstName!;
        }

        if (user.email != null && user.email!.isNotEmpty) {
          return user.email!.split('@').first;
        }
      }

      return 'المستخدم';
    } catch (e) {
      debugPrint('Error getting user display name: $e');
      return 'المستخدم';
    }
  }
}
