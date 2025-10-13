import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:marmooq/core/services/auth_exception.dart';

/// GraphQL Authentication Service for Shopify Storefront API
class GraphQLAuthService {
  static const String _storeUrl = 'fagk1b-a1.myshopify.com';
  static const String _apiVersion = '2025-07';

  static String get _storefrontAccessToken =>
      dotenv.env['SHOPIFY_STOREFRONT_TOKEN'] ?? '';

  static String get _graphqlEndpoint =>
      'https://$_storeUrl/api/$_apiVersion/graphql.json';

  /// GraphQL mutation for customer sign in
  static const String _signInMutation = r'''
    mutation customerAccessTokenCreate($input: CustomerAccessTokenCreateInput!) {
      customerAccessTokenCreate(input: $input) {
        customerAccessToken {
          accessToken
          expiresAt
        }
        customerUserErrors {
          code
          field
          message
        }
      }
    }
  ''';

  /// GraphQL mutation for customer registration
  static const String _signUpMutation = r'''
    mutation customerCreate($input: CustomerCreateInput!) {
      customerCreate(input: $input) {
        customer {
          id
          email
          firstName
          lastName
          phone
        }
        customerUserErrors {
          code
          field
          message
        }
      }
    }
  ''';

  /// GraphQL query to get customer details
  static const String _customerQuery = r'''
    query getCustomer($customerAccessToken: String!) {
      customer(customerAccessToken: $customerAccessToken) {
        id
        email
        firstName
        lastName
        phone
        displayName
        defaultAddress {
          id
          address1
          address2
          city
          province
          country
          zip
          phone
        }
      }
    }
  ''';

  /// Sign in with email and password using GraphQL
  /// Returns a Map with accessToken, expiresAt, and customer data
  static Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final variables = {
        'input': {'email': email, 'password': password},
      };

      final response = await _executeGraphQL(
        query: _signInMutation,
        variables: variables,
      );

      final data = response['data'] as Map<String, dynamic>?;
      final tokenData =
          data?['customerAccessTokenCreate'] as Map<String, dynamic>?;

      // Check for user errors
      final userErrors = tokenData?['customerUserErrors'] as List<dynamic>?;
      if (userErrors != null && userErrors.isNotEmpty) {
        final error = userErrors.first as Map<String, dynamic>;
        throw AuthException(
          error['message'] as String? ?? 'Sign in failed',
          code: error['code'] as String?,
        );
      }

      final accessTokenData =
          tokenData?['customerAccessToken'] as Map<String, dynamic>?;
      if (accessTokenData == null) {
        throw AuthException('Failed to retrieve access token');
      }

      final accessToken = accessTokenData['accessToken'] as String;
      final expiresAt = accessTokenData['expiresAt'] as String?;

      // Fetch customer details with the access token
      final customerData = await getCustomer(accessToken: accessToken);

      return {
        'accessToken': accessToken,
        'expiresAt': expiresAt,
        'customer': customerData,
      };
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('GraphQL sign in error: $e');
      throw AuthException('Sign in failed: ${e.toString()}');
    }
  }

  /// Register a new customer using GraphQL
  /// Returns a Map with customer data
  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone, // Made optional
    bool? acceptsMarketing,
  }) async {
    try {
      // Build input map
      final inputMap = {
        'email': email,
        'password': password,
        'firstName': firstName,
        'lastName': lastName,
        'acceptsMarketing': acceptsMarketing ?? false,
      };

      // Only add phone if provided and non-empty
      if (phone != null && phone.isNotEmpty) {
        // Ensure no spaces or special characters except +
        final phoneToSend = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
        inputMap['phone'] = phoneToSend;
      }

      final variables = {'input': inputMap};

      debugPrint('[GraphQL] Registration variables: ${json.encode(variables)}');

      final response = await _executeGraphQL(
        query: _signUpMutation,
        variables: variables,
      );

      final data = response['data'] as Map<String, dynamic>?;
      final createData = data?['customerCreate'] as Map<String, dynamic>?;

      // Check for user errors
      final userErrors = createData?['customerUserErrors'] as List<dynamic>?;
      if (userErrors != null && userErrors.isNotEmpty) {
        debugPrint('[GraphQL] User errors: ${json.encode(userErrors)}');
        final error = userErrors.first as Map<String, dynamic>;
        final errorMsg = error['message'] as String? ?? 'Registration failed';
        final errorField = error['field'] as List<dynamic>?;

        // If phone error and phone was provided, retry without phone
        if (errorField != null &&
            errorField.contains('phone') &&
            phone != null &&
            phone.isNotEmpty) {
          debugPrint(
            '[GraphQL] Phone validation failed by Shopify, retrying without phone',
          );
          debugPrint('[GraphQL] Original phone: $phone');

          // Retry registration without phone - will succeed
          final result = await signUp(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName,
            phone: null, // Skip phone this time
            acceptsMarketing: acceptsMarketing,
          );

          // Add a flag to indicate phone was skipped
          result['phoneSkipped'] = true;
          return result;
        }

        throw AuthException(errorMsg, code: error['code'] as String?);
      }

      final customer = createData?['customer'] as Map<String, dynamic>?;
      if (customer == null) {
        throw AuthException('Failed to create customer');
      }

      // After successful registration, sign in to get access token
      final signInResult = await signIn(email: email, password: password);

      return {
        'customer': customer,
        'accessToken': signInResult['accessToken'],
        'expiresAt': signInResult['expiresAt'],
      };
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('GraphQL sign up error: $e');
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  /// Get customer details using access token
  static Future<Map<String, dynamic>> getCustomer({
    required String accessToken,
  }) async {
    try {
      final variables = {'customerAccessToken': accessToken};

      final response = await _executeGraphQL(
        query: _customerQuery,
        variables: variables,
      );

      final data = response['data'] as Map<String, dynamic>?;
      final customer = data?['customer'] as Map<String, dynamic>?;

      if (customer == null) {
        throw AuthException('Failed to retrieve customer data');
      }

      return customer;
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('GraphQL get customer error: $e');
      throw AuthException('Failed to get customer: ${e.toString()}');
    }
  }

  /// Execute GraphQL query/mutation
  static Future<Map<String, dynamic>> _executeGraphQL({
    required String query,
    Map<String, dynamic>? variables,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_graphqlEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'X-Shopify-Storefront-Access-Token': _storefrontAccessToken,
        },
        body: json.encode({
          'query': query,
          if (variables != null) 'variables': variables,
        }),
      );

      if (response.statusCode != 200) {
        throw AuthException(
          'GraphQL request failed with status: ${response.statusCode}',
        );
      }

      final responseData = json.decode(response.body) as Map<String, dynamic>;

      // Check for GraphQL errors
      final errors = responseData['errors'] as List<dynamic>?;
      if (errors != null && errors.isNotEmpty) {
        final error = errors.first as Map<String, dynamic>;
        throw AuthException(
          error['message'] as String? ?? 'GraphQL error occurred',
        );
      }

      return responseData;
    } catch (e) {
      if (e is AuthException) rethrow;
      debugPrint('GraphQL execution error: $e');
      throw AuthException('GraphQL request failed: ${e.toString()}');
    }
  }
}
