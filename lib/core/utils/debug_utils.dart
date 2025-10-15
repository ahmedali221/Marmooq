import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class DebugUtils {
  /// Validates Shopify configuration and prints debug information
  static void validateShopifyConfig() {
    if (kDebugMode) {
      print('=== SHOPIFY CONFIGURATION DEBUG ===');

      // Check environment variables
      final storefrontToken = dotenv.env['SHOPIFY_STOREFRONT_TOKEN'];
      final adminToken = dotenv.env['ADMIN_ACCESS_TOKEN'];

      print(
        'Storefront Token: ${storefrontToken?.isNotEmpty == true ? 'Present' : 'MISSING'}',
      );
      print(
        'Admin Token: ${adminToken?.isNotEmpty == true ? 'Present' : 'MISSING'}',
      );

      if (storefrontToken?.isEmpty == true) {
        print('❌ ERROR: SHOPIFY_STOREFRONT_TOKEN is empty or missing');
      }

      if (adminToken?.isEmpty == true) {
        print('❌ ERROR: ADMIN_ACCESS_TOKEN is empty or missing');
      }

      // Check store URL
      const storeUrl = 'fagk1b-a1.myshopify.com';
      print('Store URL: $storeUrl');

      // Check API version
      const apiVersion = '2025-07';
      print('API Version: $apiVersion');

      print('=== END CONFIGURATION DEBUG ===');
    }
  }

  /// Validates cart data before checkout creation
  static void validateCartData({
    required String email,
    required String customerAccessToken,
    required List<dynamic> lineItems,
  }) {
    if (kDebugMode) {
      print('=== CART VALIDATION DEBUG ===');

      print('Email: ${email.isNotEmpty ? 'Valid' : 'INVALID - Empty'}');
      print(
        'Customer Access Token: ${customerAccessToken.isNotEmpty ? 'Present' : 'MISSING'}',
      );
      print('Line Items Count: ${lineItems.length}');

      if (lineItems.isEmpty) {
        print('❌ ERROR: Cart is empty');
      }

      for (int i = 0; i < lineItems.length; i++) {
        final item = lineItems[i];
        print('Item $i: ${item.toString()}');
      }

      print('=== END CART VALIDATION ===');
    }
  }

  /// Prints network connectivity status
  static void printNetworkStatus() {
    if (kDebugMode) {
      print('=== NETWORK STATUS ===');
      print('Store URL: https://fagk1b-a1.myshopify.com');
      print(
        'GraphQL Endpoint: https://fagk1b-a1.myshopify.com/api/2025-07/graphql.json',
      );
      print('=== END NETWORK STATUS ===');
    }
  }
}
