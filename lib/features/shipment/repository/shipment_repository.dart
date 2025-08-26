import 'package:flutter/foundation.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

class ShipmentRepository {
  final ShopifyCustomer _shopifyCustomer = ShopifyCustomer.instance;
  final ShopifyCart _shopifyCart = ShopifyCart.instance;
  final ShopifyCustom _shopifyCustom = ShopifyCustom.instance;

  Future<void> createCustomerAddress({
    required String customerAccessToken,
    required String address1,
    String? address2,
    required String city,
    required String country,
    required String province,
    required String zip,
    required String firstName,
    required String lastName,
    String? phone,
    String? company,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Debug: Creating customer address with:');
        debugPrint('  customerAccessToken: $customerAccessToken');
        debugPrint(
          '  address1: $address1, city: $city, country: $country, province: $province, zip: $zip',
        );
        debugPrint(
          '  firstName: $firstName, lastName: $lastName, phone: $phone, company: $company',
        );
      }

      await _shopifyCustomer.customerAddressCreate(
        customerAccessToken: customerAccessToken,
        address1: address1,
        address2: address2,
        city: city,
        country: country,
        province: province,
        zip: zip,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        company: company,
      );

      if (kDebugMode) {
        debugPrint('Debug: Customer address created successfully');
      }
    } catch (e) {
      // Check if the error is about duplicate address
      if (e.toString().contains('Address already exists for customer')) {
        if (kDebugMode) {
          debugPrint('Debug: Address already exists, skipping creation');
        }
        // Don't throw exception for duplicate address, just log it
        return;
      }
      
      final errorMessage = 'Failed to create customer address: $e';
      if (kDebugMode) {
        debugPrint('Debug: $errorMessage');
      }
      throw Exception(errorMessage);
    }
  }

  Future<void> updateCartBuyerIdentity({
    required String cartId,
    required String email,
    required String countryCode,
    required String address1,
    String? address2,
    required String city,
    required String province,
    required String zip,
    required String firstName,
    required String lastName,
    String? phone,
    String? company,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('Debug: Updating cart buyer identity for cartId: $cartId');
        debugPrint('  email: $email, countryCode: $countryCode');
        debugPrint(
          '  address1: $address1, city: $city, province: $province, zip: $zip',
        );
        debugPrint(
          '  firstName: $firstName, lastName: $lastName, phone: $phone, company: $company',
        );
      }

      // Map country codes to full country names
      String getCountryName(String countryCode) {
        switch (countryCode.toUpperCase()) {
          case 'KW':
            return 'Kuwait';
          case 'US':
            return 'United States';
          case 'CA':
            return 'Canada';
          case 'GB':
            return 'United Kingdom';
          case 'AU':
            return 'Australia';
          case 'DE':
            return 'Germany';
          case 'FR':
            return 'France';
          case 'ES':
            return 'Spain';
          case 'IT':
            return 'Italy';
          case 'JP':
            return 'Japan';
          case 'CN':
            return 'China';
          case 'IN':
            return 'India';
          case 'BR':
            return 'Brazil';
          case 'MX':
            return 'Mexico';
          case 'AE':
            return 'United Arab Emirates';
          case 'SA':
            return 'Saudi Arabia';
          default:
            return countryCode; // Fallback to country code if not mapped
        }
      }

      // Create a proper delivery address input with full country name
      final deliveryAddress = MailingAddressInput(
        address1: address1,
        address2: address2,
        city: city,
        province: province,
        zip: zip,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        company: company,
        country: getCountryName(countryCode), // This should now use "Kuwait" instead of "KW"
      );
      
      // Add debug print to verify the country name mapping
      if (kDebugMode) {
        debugPrint('Debug: Using country name: ${getCountryName(countryCode)} for countryCode: $countryCode');
      }
      
      await _shopifyCart.updateBuyerIdentityInCart(
        cartId: cartId,
        buyerIdentity: CartBuyerIdentityInput(
          email: email,
          countryCode: countryCode, // Keep ISO code for countryCode
          phone: phone,
          deliveryAddressPreferences: [
            DeliveryAddressInput(
              deliveryAddress: deliveryAddress,
            ),
          ],
        ),
      );

      if (kDebugMode) {
        debugPrint('Debug: Cart buyer identity updated successfully');
      }
    } catch (e) {
      final errorMessage = 'Failed to update cart buyer identity: $e';
      if (kDebugMode) {
        debugPrint('Debug: $errorMessage');
      }
      throw Exception(errorMessage);
    }
  }

  Future<Map<String, dynamic>> createCheckout({
    required String email,
    required String address1,
    String? address2,
    required String city,
    required String country,
    required String province,
    required String zip,
    required String firstName,
    required String lastName,
    String? phone,
    String? company,
    required List<CartLineInput> lineItems,
  }) async {
    const mutation = '''
    mutation checkoutCreate(\$input: CheckoutCreateInput!) {
      checkoutCreate(input: \$input) {
        checkout {
          id
          webUrl
          shippingAddress {
            address1
            city
            country
            zip
          }
          availableShippingRates {
            shippingRates {
              handle
              title
              price {
                amount
                currencyCode
              }
            }
          }
        }
        checkoutUserErrors {
          field
          message
        }
      }
    ''';

    final variables = {
      "input": {
        "email": email,
        "shippingAddress": {
          "address1": address1,
          "address2": address2,
          "city": city,
          "country": country,
          "province": province,
          "zip": zip,
          "firstName": firstName,
          "lastName": lastName,
          "phone": phone,
          "company": company,
        },
        "lineItems": lineItems
            .map(
              (item) => {
                "merchandiseId": item.merchandiseId,
                "quantity": item.quantity,
              },
            )
            .toList(),
      },
    };

    try {
      if (kDebugMode) {
        debugPrint('Debug: Creating checkout with:');
        debugPrint('  email: $email');
        debugPrint(
          '  shippingAddress: $address1, $city, $country, $province, $zip',
        );
        debugPrint('  lineItems count: ${lineItems.length}');
        for (var item in lineItems) {
          debugPrint(
            '  - merchandiseId: ${item.merchandiseId}, quantity: ${item.quantity}',
          );
        }
      }

      final result = await _shopifyCustom.customMutation(
        gqlMutation: mutation,
        variables: variables,
      );

      // Check for user errors
      final checkoutUserErrors =
          result?['checkoutCreate']?['checkoutUserErrors'] as List<dynamic>?;
      if (checkoutUserErrors != null && checkoutUserErrors.isNotEmpty) {
        final errorMessage =
            'Checkout creation failed: ${checkoutUserErrors.map((e) => e['message']).join(', ')}';
        if (kDebugMode) {
          debugPrint('Debug: $errorMessage');
          debugPrint('Debug: Full checkoutUserErrors: $checkoutUserErrors');
        }
        throw Exception(errorMessage);
      }

      // Ensure checkout object exists
      final checkout =
          result?['checkoutCreate']?['checkout'] as Map<String, dynamic>?;
      if (checkout == null) {
        final errorMessage =
            'Failed to create checkout: No checkout data returned';
        if (kDebugMode) {
          debugPrint('Debug: $errorMessage');
        }
        throw Exception(errorMessage);
      }

      if (kDebugMode) {
        debugPrint(
          'Debug: Checkout created successfully - ID: ${checkout['id']}, webUrl: ${checkout['webUrl']}',
        );
        debugPrint(
          'Debug: Available shipping rates: ${checkout['availableShippingRates']?['shippingRates']}',
        );
      }

      return checkout;
    } catch (e) {
      final errorMessage = 'Failed to create checkout: $e';
      if (kDebugMode) {
        debugPrint('Debug: $errorMessage');
      }
      throw Exception(errorMessage);
    }
  }
}
