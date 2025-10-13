import 'package:flutter/foundation.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/core/services/security_service.dart';
import 'package:marmooq/core/utils/validation_utils.dart';
import 'package:marmooq/core/services/auth_exception.dart';
import 'package:marmooq/core/services/graphql_auth_service.dart';

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

  /// Sign in with email and password using GraphQL
  /// Returns the ShopifyUser on success
  /// Throws an AuthException on failure
  Future<ShopifyUser> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // Use GraphQL for authentication
      final result = await GraphQLAuthService.signIn(
        email: email,
        password: password,
      );

      final accessToken = result['accessToken'] as String;
      final expiresAtStr = result['expiresAt'] as String?;
      final customerData = result['customer'] as Map<String, dynamic>;

      // Store the access token securely
      await SecurityService.storeAccessToken(accessToken);

      // Store token expiration date
      if (expiresAtStr != null) {
        try {
          final expiresAt = DateTime.parse(expiresAtStr);
          await SecurityService.storeTokenExpirationDate(expiresAt);
        } catch (e) {
          debugPrint('Error parsing expiration date: $e');
          // Set default expiration to 24 hours if parsing fails
          final defaultExpiration = DateTime.now().add(
            const Duration(hours: 24),
          );
          await SecurityService.storeTokenExpirationDate(defaultExpiration);
        }
      } else {
        // Set default expiration to 24 hours if not provided
        final defaultExpiration = DateTime.now().add(const Duration(hours: 24));
        await SecurityService.storeTokenExpirationDate(defaultExpiration);
      }

      // Store user data securely
      final userData = <String, dynamic>{
        'email': customerData['email'],
        'firstName': customerData['firstName'],
        'lastName': customerData['lastName'],
        'phone': customerData['phone'],
        'id': customerData['id'],
      };
      await SecurityService.syncUserDataWithShopify(userData);

      // Generate a new session ID for this login
      await SecurityService.generateSessionId();

      // Create ShopifyUser from JSON
      final user = ShopifyUser.fromJson(customerData);
      return user;
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('Sign in error: $e');
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  /// Create a new user account with email and password using GraphQL
  /// Required fields: firstName, lastName
  /// Optional fields: phone, acceptsMarketing
  /// Returns the ShopifyUser on success
  /// Throws an AuthException on failure
  Future<ShopifyUser> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? phone, // Made optional
    required String firstName,
    required String lastName,
    bool? acceptsMarketing,
  }) async {
    try {
      // Validate phone format if provided
      if (phone != null && phone.isNotEmpty) {
        if (!phone.startsWith('+965')) {
          throw AuthException(
            'Invalid phone number format. Must be a Kuwait number with +965 prefix.',
          );
        }

        // Ensure phone is exactly 12 characters: +965XXXXXXXX
        if (phone.length != 12) {
          throw AuthException(
            'Invalid phone number format. Must be +965 followed by 8 digits.',
          );
        }

        // Validate the 8 digits start with 5, 6, or 9
        final phoneDigits = phone.substring(4); // Get the 8 digits after +965
        if (!RegExp(r'^[569]\d{7}$').hasMatch(phoneDigits)) {
          throw AuthException(
            'Invalid phone number. Must start with 5, 6, or 9.',
          );
        }

        debugPrint('[AuthService] Registering with phone: $phone');
      } else {
        debugPrint('[AuthService] Registering without phone');
      }

      // Use GraphQL for registration
      final result = await GraphQLAuthService.signUp(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        acceptsMarketing: acceptsMarketing,
      );

      final accessToken = result['accessToken'] as String;
      final expiresAtStr = result['expiresAt'] as String?;
      final customerData = result['customer'] as Map<String, dynamic>;
      final phoneSkipped = result['phoneSkipped'] as bool? ?? false;

      // Log if phone was skipped due to Shopify validation
      if (phoneSkipped) {
        debugPrint(
          '[AuthService] ⚠️ Registration completed without phone number (Shopify rejected the phone format)',
        );
      }

      // Store the access token securely
      await SecurityService.storeAccessToken(accessToken);

      // Store token expiration date
      if (expiresAtStr != null) {
        try {
          final expiresAt = DateTime.parse(expiresAtStr);
          await SecurityService.storeTokenExpirationDate(expiresAt);
        } catch (e) {
          debugPrint('Error parsing expiration date: $e');
          // Set default expiration to 24 hours if parsing fails
          final defaultExpiration = DateTime.now().add(
            const Duration(hours: 24),
          );
          await SecurityService.storeTokenExpirationDate(defaultExpiration);
        }
      } else {
        // Set default expiration to 24 hours if not provided
        final defaultExpiration = DateTime.now().add(const Duration(hours: 24));
        await SecurityService.storeTokenExpirationDate(defaultExpiration);
      }

      // Store user data securely
      final userData = <String, dynamic>{
        'email': customerData['email'] ?? email,
        'firstName': customerData['firstName'] ?? firstName,
        'lastName': customerData['lastName'] ?? lastName,
        'phone': customerData['phone'] ?? phone,
        'id': customerData['id'],
      };
      await SecurityService.syncUserDataWithShopify(userData);

      // Generate a new session ID for this registration
      await SecurityService.generateSessionId();

      // Create ShopifyUser from JSON
      final user = ShopifyUser.fromJson(customerData);
      return user;
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('Registration error: $e');
      throw AuthException('Registration failed: ${e.toString()}');
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
  /// Set forceRefresh to true to bypass cache or use GraphQL
  Future<ShopifyUser?> currentUser({bool forceRefresh = false}) async {
    try {
      // First try to get from stored token using GraphQL
      final storedToken = await SecurityService.getAccessToken();
      if (storedToken != null && storedToken.isNotEmpty) {
        try {
          final customerData = await GraphQLAuthService.getCustomer(
            accessToken: storedToken,
          );
          return ShopifyUser.fromJson(customerData);
        } catch (e) {
          debugPrint('GraphQL get customer error: $e');
          // Fall back to SDK method
        }
      }

      // Fallback to SDK method
      return await _shopifyAuth.currentUser(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('Get current user error: $e');
      return null;
    }
  }

  /// Update the current Shopify customer profile
  /// Any provided field will be updated; leave null to keep existing
  Future<ShopifyUser> updateCustomer({
    String? firstName,
    String? lastName,
    String? phone,
    String? email,
    bool? acceptsMarketing,
  }) async {
    try {
      // Validate and normalize phone - only send if it's valid
      String? normalizedPhone;
      if (phone != null && phone.trim().isNotEmpty) {
        normalizedPhone = ValidationUtils.normalizeKuwaitPhone(phone);
        // If normalization fails (returns empty string), don't send phone at all
        if (normalizedPhone.isEmpty) {
          throw AuthException(
            'Invalid phone number format. Must be 8 digits starting with 5, 6, or 9',
          );
        }
      }

      // Retrieve the current customer access token (required by Shopify)
      String? customerAccessToken = await SecurityService.getAccessToken();
      customerAccessToken ??= await _shopifyAuth.currentCustomerAccessToken;
      if (customerAccessToken == null || customerAccessToken.isEmpty) {
        throw AuthException('Missing customer access token');
      }

      final customer = ShopifyCustomer.instance;
      await customer.customerUpdate(
        firstName: firstName,
        lastName: lastName,
        phoneNumber: normalizedPhone,
        email: email,
        customerAccessToken: customerAccessToken,
        acceptsMarketing: acceptsMarketing,
      );
      debugPrint(
        '[AuthService] customerUpdate (profile) called with phone=' +
            (normalizedPhone ?? '(null)'),
      );

      // Verify phone persisted; retry once if needed
      if (normalizedPhone != null) {
        try {
          final verifyUser = await _shopifyAuth.currentUser(forceRefresh: true);
          final currentPhone = verifyUser?.phone;
          debugPrint(
            '[AuthService] Post-update verify phone=' +
                (currentPhone ?? '(empty)'),
          );
          if (currentPhone == null || currentPhone.isEmpty) {
            await Future.delayed(const Duration(milliseconds: 300));
            await customer.customerUpdate(
              phoneNumber: normalizedPhone,
              customerAccessToken: customerAccessToken,
            );
            debugPrint('[AuthService] Retried setting phone after delay');
          }
        } catch (e) {
          debugPrint('Phone verification after update failed: ' + e.toString());
        }
      }

      // Refresh current user data after update
      final updated = await _shopifyAuth.currentUser(forceRefresh: true);
      if (updated != null) {
        final userData = <String, dynamic>{
          'email': updated.email,
          'firstName': updated.firstName,
          'lastName': updated.lastName,
          'phone': updated.phone,
          'id': updated.id,
        };
        await SecurityService.syncUserDataWithShopify(userData);
        return updated;
      }
      // Fallback: fetch without force if null returned
      final fallback = await _shopifyAuth.currentUser();
      if (fallback != null) return fallback;
      throw AuthException('Failed to refresh user after update');
    } catch (e) {
      debugPrint('Shopify update customer error: $e');
      throw AuthException.fromShopifyError(e);
    }
  }

  /// List addresses for the current customer
  Future<List<Address>> listAddresses() async {
    try {
      final token =
          await SecurityService.getAccessToken() ??
          await _shopifyAuth.currentCustomerAccessToken;
      if (token == null || token.isEmpty) {
        throw AuthException('Missing customer access token');
      }
      // Fetch addresses via customerAddressCreate/delete/update requires token,
      // but to list addresses, we can fetch the current user and parse nodes if available.
      // Fallback: return empty list if SDK doesn't expose addresses here.
      final user = await _shopifyAuth.currentUser(forceRefresh: true);
      try {
        // Some versions expose defaultAddress and addresses; guard by runtime checks
        final dynamic dyn = user;
        if (dyn != null && dyn.toJson is Function) {
          final map = dyn.toJson() as Map<String, dynamic>;
          final edges = (map['addresses']?['edges'] as List?) ?? [];
          return edges
              .map((e) => e['node'])
              .where((n) => n != null)
              .map<Address>((n) => Address.fromJson(n as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
      return <Address>[];
    } catch (e) {
      debugPrint('Shopify list addresses error: $e');
      rethrow;
    }
  }

  /// Create a new address
  Future<Address> createAddress({
    String? address1,
    String? address2,
    String? company,
    String? city,
    String? country,
    String? firstName,
    String? lastName,
    String? phone,
    String? province,
    String? zip,
  }) async {
    try {
      final token =
          await SecurityService.getAccessToken() ??
          await _shopifyAuth.currentCustomerAccessToken;
      if (token == null || token.isEmpty) {
        throw AuthException('Missing customer access token');
      }

      // Validate and normalize phone if provided
      String? validatedPhone;
      if (phone != null && phone.trim().isNotEmpty) {
        validatedPhone = ValidationUtils.normalizeKuwaitPhone(phone);
        if (validatedPhone.isEmpty) {
          throw AuthException(
            'Invalid phone number format. Must be 8 digits starting with 5, 6, or 9',
          );
        }
      }

      final customer = ShopifyCustomer.instance;
      return await customer.customerAddressCreate(
        address1: address1,
        address2: address2,
        company: company,
        city: city,
        country: country,
        firstName: firstName,
        lastName: lastName,
        phone: validatedPhone,
        province: province,
        zip: zip,
        customerAccessToken: token,
      );
    } catch (e) {
      debugPrint('Shopify create address error: $e');
      rethrow;
    }
  }

  /// Update an existing address
  Future<void> updateAddress({
    required String id,
    String? address1,
    String? address2,
    String? company,
    String? city,
    String? country,
    String? firstName,
    String? lastName,
    String? phone,
    String? province,
    String? zip,
  }) async {
    try {
      final token =
          await SecurityService.getAccessToken() ??
          await _shopifyAuth.currentCustomerAccessToken;
      if (token == null || token.isEmpty) {
        throw AuthException('Missing customer access token');
      }

      // Validate and normalize phone if provided
      String? validatedPhone;
      if (phone != null && phone.trim().isNotEmpty) {
        validatedPhone = ValidationUtils.normalizeKuwaitPhone(phone);
        if (validatedPhone.isEmpty) {
          throw AuthException(
            'Invalid phone number format. Must be 8 digits starting with 5, 6, or 9',
          );
        }
      }

      final customer = ShopifyCustomer.instance;
      await customer.customerAddressUpdate(
        customerAccessToken: token,
        id: id,
        address1: address1,
        address2: address2,
        company: company,
        city: city,
        country: country,
        firstName: firstName,
        lastName: lastName,
        phone: validatedPhone,
        province: province,
        zip: zip,
      );
    } catch (e) {
      debugPrint('Shopify update address error: $e');
      rethrow;
    }
  }

  /// Delete an address by id
  Future<void> deleteAddress({required String addressId}) async {
    try {
      final token =
          await SecurityService.getAccessToken() ??
          await _shopifyAuth.currentCustomerAccessToken;
      if (token == null || token.isEmpty) {
        throw AuthException('Missing customer access token');
      }
      final customer = ShopifyCustomer.instance;
      await customer.customerAddressDelete(
        customerAccessToken: token,
        addressId: addressId,
      );
    } catch (e) {
      debugPrint('Shopify delete address error: $e');
      rethrow;
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

      // Verify with GraphQL first
      try {
        final customerData = await GraphQLAuthService.getCustomer(
          accessToken: storedToken,
        );
        // If we can get customer data, authentication is valid
        return customerData['id'] != null;
      } catch (e) {
        debugPrint('GraphQL authentication check failed: $e');
        // Clear auth data if GraphQL check fails
        await SecurityService.clearAllAuthData();
        return false;
      }
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
