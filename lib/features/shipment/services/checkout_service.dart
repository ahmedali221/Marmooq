import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/checkout_models.dart';
import 'shopify_admin_service.dart';

class CheckoutService {
  final _shopifyCustom = ShopifyCustom.instance;
  final _adminService = ShopifyAdminService();

  Future<CheckoutResult> completeCODCheckout({
    required List<CartLineInput> lineItems,
    required String cartId,
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
    required String address1,
    String customerAccessToken = '',
  }) async {
    try {
      print('🚀 Starting COD checkout process...');
      print('🔗 CHECKOUT STARTED - Cart ID: $cartId');
      print('🔗 CHECKOUT STARTED - Customer: $email');

      // Step 1: Validate cart items
      print('📋 Validating cart items...');
      await _validateCartItems(lineItems);
      print('✅ Cart items validated');

      // Step 2: Update customer phone (optional)
      final envCustomerToken = dotenv.env['SHOPIFY_CUSTOMER_API_TOKEN'];
      final tokenToUse = customerAccessToken.isNotEmpty
          ? customerAccessToken
          : envCustomerToken ?? '';

      if (tokenToUse.isNotEmpty) {
        try {
          print('📞 Updating customer phone...');
          await _updateCustomerPhone(tokenToUse, phone);
          print('✅ Customer phone updated');
        } catch (e) {
          print('⚠️ Failed to update customer phone: $e');
          // Continue even if phone update fails
        }
      }

      // Step 3: Create and complete order using Admin API
      print('🏪 Creating COD order via Admin API...');
      final orderDetails = await _adminService.createAndCompleteCODOrder(
        lineItems: lineItems,
        email: email,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
        address1: address1,
        city: 'Kuwait City',
        province: 'Al Asimah',
        zip: '00000',
        countryCode: 'KW',
      );

      print('🎉 Order completed successfully: ${orderDetails['orderNumber']}');

      // Log checkout and order URLs for testing
      final orderId = orderDetails['orderId'] as String? ?? 'unknown';
      final orderName = orderDetails['orderName'] as String? ?? 'unknown';

      // Extract order ID from GID format (gid://shopify/DraftOrder/123456 -> 123456)
      final cleanOrderId = orderId.replaceAll('gid://shopify/DraftOrder/', '');

      final checkoutUrl =
          'https://fagk1b-a1.myshopify.com/checkout/$cleanOrderId';
      final orderUrl =
          'https://fagk1b-a1.myshopify.com/admin/orders/$cleanOrderId';

      print('🔗 CHECKOUT URL: $checkoutUrl');
      print('🔗 ORDER URL: $orderUrl');
      print('🔗 ORDER NAME: $orderName');
      print('🔗 ORDER ID: $cleanOrderId');

      return CheckoutResult.success(
        url: orderUrl,
        checkoutId: orderDetails['orderName'],
        totalPrice: orderDetails['totalPrice'],
        autoRedirect: true,
      );
    } catch (e) {
      print('❌ COD checkout failed: $e');
      return CheckoutResult.error('فشل في إتمام الطلب: ${e.toString()}');
    }
  }

  Future<void> _validateCartItems(List<CartLineInput> lineItems) async {
    for (final item in lineItems) {
      if (!await validateMerchandiseId(item.merchandiseId))
        throw Exception('المنتج غير متوفر');
    }
  }

  Future<void> _updateCustomerPhone(String token, String phone) async {
    const mutation =
        r'mutation customerUpdate($customerAccessToken: String!, $customer: CustomerUpdateInput!) { customerUpdate(customerAccessToken: $customerAccessToken, customer: $customer) { customer { id phone } userErrors { field message } } }';
    await _shopifyCustom.customQuery(
      gqlQuery: mutation,
      variables: {
        'customerAccessToken': token,
        'customer': {'phone': phone},
      },
    );
  }

  Future<bool> validateMerchandiseId(String id) async {
    const query =
        r'query getVariant($id: ID!) { node(id: $id) { ... on ProductVariant { id } } }';
    final result = await _shopifyCustom.customQuery(
      gqlQuery: query,
      variables: {'id': id},
    );
    return result?['node'] != null;
  }

  /// Validates merchandise IDs in the cart
  Future<bool> validateCartItems(List<CartLineInput> lineItems) async {
    try {
      for (var item in lineItems) {
        final isValid = await validateMerchandiseId(item.merchandiseId);
        if (!isValid) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
