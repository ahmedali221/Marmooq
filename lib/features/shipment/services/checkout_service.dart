import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'package:marmooq/features/shipment/models/checkout_models.dart';
import 'package:marmooq/features/shipment/repository/shipment_repository.dart';

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
      // Basic validation
      if (email.isEmpty) throw Exception('Email is required for checkout');
      if (customerAccessToken.isEmpty)
        throw Exception('Customer access token is required');
      if (lineItems.isEmpty)
        throw Exception('Cart is empty - cannot create checkout');

      final checkoutResult = await _shipmentRepository.createCheckout(
        email: email,
        cartId: cartId,
        customerAccessToken: customerAccessToken,
        lineItems: lineItems,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
      );

      return CheckoutData.fromMap(checkoutResult);
    } catch (e) {
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

    // Format phone number properly
    final String finalPhone =
        (phone.isNotEmpty && phone.startsWith('+965') && phone.length == 13)
        ? phone
        : '+96555544789'; // Demo phone fallback

    addIfNotEmpty('checkout[shipping_address][phone]', finalPhone);
    addIfNotEmpty('checkout[phone]', finalPhone);
    addIfNotEmpty('checkout[shipping_address][country_code]', 'KW');
    addIfNotEmpty('checkout[shipping_address][province_code]', 'KU');

    final newUri = uri.replace(queryParameters: params);
    return newUri.toString();
  }

  /// Validates merchandise IDs in the cart
  Future<bool> validateCartItems(List<CartLineInput> lineItems) async {
    try {
      for (var item in lineItems) {
        final isValid = await _shipmentRepository.validateMerchandiseId(
          item.merchandiseId,
        );
        if (!isValid) return false;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String> completeCODCheckout({
    required String cartId,
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
    required String address,
  }) async {
    try {
      // Create a new cart with buyer identity and COD attributes
      final cartInput = CartInput(
        lines: [], // We'll add items from the existing cart
        buyerIdentity: CartBuyerIdentityInput(email: email, phone: phone),
        attributes: [
          AttributeInput(key: 'payment_method', value: 'COD'),
          AttributeInput(key: 'delivery_address', value: address),
          AttributeInput(key: 'customer_name', value: '$firstName $lastName'),
        ],
      );

      // Create new cart for COD order
      final newCart = await ShopifyCart.instance.createCart(cartInput);

      if (newCart.id.isEmpty) {
        throw Exception('Failed to create COD cart');
      }

      // Get the original cart to copy line items
      final originalCart = await ShopifyCart.instance.getCartById(cartId);

      if (originalCart?.lines.isEmpty ?? true) {
        throw Exception('Original cart is empty');
      }

      // Convert line items to add to new cart
      final lineItems = originalCart!.lines
          .where((line) => line.merchandise?.id != null)
          .map(
            (line) => CartLineInput(
              merchandiseId: line.merchandise!.id,
              quantity: line.quantity ?? 1,
            ),
          )
          .toList();

      if (lineItems.isEmpty) {
        throw Exception('No valid line items found');
      }

      // Add line items to the new COD cart
      final lineUpdateInputs = lineItems
          .map(
            (item) => CartLineUpdateInput(
              merchandiseId: item.merchandiseId,
              quantity: item.quantity,
            ),
          )
          .toList();

      await ShopifyCart.instance.addLineItemsToCart(
        cartId: newCart.id,
        cartLineInputs: lineUpdateInputs,
      );

      // For COD, we simulate order completion by returning a mock order ID
      // In a real implementation, you would integrate with your payment processor
      // and use the checkout URL from the repository if needed
      final orderId = 'COD-${DateTime.now().millisecondsSinceEpoch}';

      return orderId;
    } catch (e) {
      throw Exception('فشل في تأكيد الطلب: $e');
    }
  }

  /// Updates customer phone number before checkout
  Future<bool> updateCustomerPhone({
    required String customerAccessToken,
    required String phone,
  }) async {
    try {
      return await _shipmentRepository.updateCustomerPhone(
        customerAccessToken: customerAccessToken,
        phone: phone,
      );
    } catch (e) {
      return false;
    }
  }

  /// Checks if a checkout is completed
  Future<bool> isCheckoutCompleted(String checkoutId) async {
    return await _shipmentRepository.isCheckoutCompleted(checkoutId);
  }
}
