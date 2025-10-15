import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/shipment/models/checkout_models.dart';
import 'package:marmooq/features/shipment/repository/shipment_repository.dart';
import 'package:marmooq/core/utils/validation_utils.dart';

class CheckoutService {
  final ShipmentRepository _shipmentRepository = ShipmentRepository();

  /// Creates a checkout with the provided details
  Future<CheckoutData> createCheckout({
    required String email,
    required String cartId,
    required String customerAccessToken,
    required List<CartLineInput> lineItems,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      print('[CheckoutService] Starting checkout creation...');
      print('[CheckoutService] Email: $email');
      print('[CheckoutService] Cart ID: $cartId');
      print(
        '[CheckoutService] Access Token Present: ${customerAccessToken.isNotEmpty}',
      );
      print('[CheckoutService] Line Items: ${lineItems.length}');

      // Pre-validation
      if (email.isEmpty) {
        throw Exception('Email is required for checkout');
      }

      if (customerAccessToken.isEmpty) {
        throw Exception('Customer access token is required for checkout');
      }

      if (lineItems.isEmpty) {
        throw Exception('Cart is empty - cannot create checkout');
      }

      final checkoutResult = await _shipmentRepository.createCheckout(
        email: email,
        cartId: cartId,
        customerAccessToken: customerAccessToken,
        lineItems: lineItems,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      print('[CheckoutService] Checkout result: $checkoutResult');
      return CheckoutData.fromMap(checkoutResult);
    } catch (e) {
      print('[CheckoutService] Error creating checkout: $e');
      throw Exception('Failed to create checkout: $e');
    }
  }

  /// Builds a prefilled checkout URL with shipping details
  String buildPrefilledCheckoutUrl({
    required String baseCheckoutUrl,
    required String email,
    required String firstName,
    required String lastName,
    required String address1,
    required String address2,
    required String city,
    required String province,
    required String country,
    required String zip,
    required String phone,
  }) {
    final uri = Uri.parse(baseCheckoutUrl);
    final Map<String, String> params = Map<String, String>.from(
      uri.queryParameters,
    );

    void addIfNotEmpty(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    // Shopify checkout prefill parameters
    addIfNotEmpty('checkout[email]', email);
    addIfNotEmpty('checkout[shipping_address][first_name]', firstName);
    addIfNotEmpty('checkout[shipping_address][last_name]', lastName);
    addIfNotEmpty('checkout[shipping_address][address1]', address1);
    addIfNotEmpty('checkout[shipping_address][address2]', address2);
    addIfNotEmpty('checkout[shipping_address][city]', city);
    addIfNotEmpty('checkout[shipping_address][province]', province);
    addIfNotEmpty('checkout[shipping_address][country]', country);
    addIfNotEmpty('checkout[shipping_address][zip]', zip);

    // Normalize Kuwait phone to +965XXXXXXXX pattern before sending
    final String phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    final String fullKuwaitPhone = phoneDigits.isEmpty
        ? ''
        : '+965' + phoneDigits;
    final String normalizedPhone = ValidationUtils.normalizeKuwaitPhone(
      fullKuwaitPhone,
    );

    print('[DEBUG] Phone normalization:');
    print('[DEBUG] Original phone: $phone');
    print('[DEBUG] Phone digits: $phoneDigits');
    print('[DEBUG] Full Kuwait phone: $fullKuwaitPhone');
    print('[DEBUG] Normalized phone: $normalizedPhone');

    addIfNotEmpty('checkout[shipping_address][phone]', normalizedPhone);

    // Additional Shopify checkout parameters for better prefill
    addIfNotEmpty('checkout[shipping_address][company]', '');
    addIfNotEmpty('checkout[shipping_address][country_code]', 'KW');
    addIfNotEmpty('checkout[shipping_address][province_code]', 'KU');

    // Set default shipping method to free delivery
    addIfNotEmpty('checkout[shipping_rate][id]', '');

    // Set default payment method to cash on delivery
    addIfNotEmpty('checkout[payment_gateway]', 'cash_on_delivery');

    final newUri = uri.replace(queryParameters: params);

    // Debug logging for URL parameters
    print('[DEBUG] Generated checkout URL parameters:');
    params.forEach((key, value) {
      if (key.contains('phone') ||
          key.contains('email') ||
          key.contains('name')) {
        print('[DEBUG] $key: $value');
      }
    });

    // Additional debug logging for phone parameter specifically
    print(
      '[DEBUG] Phone parameter in URL: ${params['checkout[shipping_address][phone]']}',
    );
    print('[DEBUG] Email parameter in URL: ${params['checkout[email]']}');
    print(
      '[DEBUG] First name parameter in URL: ${params['checkout[shipping_address][first_name]']}',
    );
    print(
      '[DEBUG] Last name parameter in URL: ${params['checkout[shipping_address][last_name]']}',
    );

    return newUri.toString();
  }

  /// Validates merchandise IDs in the cart
  Future<bool> validateCartItems(List<CartLineInput> lineItems) async {
    try {
      for (var item in lineItems) {
        final isValid = await _shipmentRepository.validateMerchandiseId(
          item.merchandiseId,
        );
        if (!isValid) {
          return false;
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Updates customer phone number before checkout
  Future<bool> updateCustomerPhone({
    required String customerAccessToken,
    required String phone,
  }) async {
    try {
      print('[CheckoutService] Updating customer phone number...');
      print('[CheckoutService] Phone: $phone');

      final success = await _shipmentRepository.updateCustomerPhone(
        customerAccessToken: customerAccessToken,
        phone: phone,
      );

      if (success) {
        print('[CheckoutService] Customer phone updated successfully');
      } else {
        print('[CheckoutService] Failed to update customer phone');
      }

      return success;
    } catch (e) {
      print('[CheckoutService] Error updating customer phone: $e');
      return false;
    }
  }

  /// Checks if a checkout is completed
  Future<bool> isCheckoutCompleted(String checkoutId) async {
    return await _shipmentRepository.isCheckoutCompleted(checkoutId);
  }
}
