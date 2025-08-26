import 'package:shopify_flutter/models/src/cart/cart.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_input/cart_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_input/cart_line_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';
import 'package:shopify_flutter/shopify/src/shopify_cart.dart';
import 'package:traincode/core/services/security_service.dart';

// Custom exception class for cart operations
class CartRepositoryException implements Exception {
  final String message;
  CartRepositoryException(this.message);

  @override
  String toString() => 'CartRepositoryException: $message';
}

class CartRepository {
  final ShopifyCart _shopifyCart = ShopifyCart.instance;

  /// Creates a new cart with optional note, discount codes, and attributes.
  /// The cart is not associated with a customer (buyerIdentity is null).
  /// Includes debugging logs for input, API call, and response.
  Future<Cart> createCart({
    String? note,
    List<String>? discountCodes,
    List<AttributeInput>? attributes,
  }) async {
    try {
      // Step 1: Log input parameters
      print('DEBUG: Preparing to create cart...');
      print(
        'DEBUG: Input parameters - note: $note, discountCodes: $discountCodes, attributes: ${attributes?.map((a) => "{key: ${a.key}, value: ${a.value}}").toList()}',
      );

      // Step 2: Create CartInput with empty lines and no buyerIdentity
      final cartInput = CartInput(
        lines: [], // No initial line items
        attributes: attributes ?? [],
        note: note ?? '',
        discountCodes: discountCodes ?? [],
        buyerIdentity:
            null, // Explicitly set to null for no customer association
      );

      // Log the serialized CartInput for the API
      print('DEBUG: CartInput serialized: ${cartInput.toJson()}');

      // Step 3: Call ShopifyCart.createCart
      print('DEBUG: Sending cartCreate mutation to Shopify API...');
      final Cart createdCart = await _shopifyCart.createCart(cartInput);

      // Step 4: Log the response
      if (createdCart.id == null) {
        print('DEBUG: Warning - Created cart has no ID');
        throw CartRepositoryException('Created cart is invalid: missing ID');
      }
      print('DEBUG: Cart created successfully!');
      print('DEBUG: Cart ID: ${createdCart.id}');
      print(
        'DEBUG: Cart details - lines: ${createdCart.lines.length}, total: ${createdCart.cost?.totalAmount?.amount ?? 0.0}',
      );

      // Store cart ID securely
      if (createdCart.id != null) {
        await SecurityService.storeCartId(createdCart.id!);
        print('DEBUG: Cart ID stored securely');
      }

      return createdCart;
    } catch (e, stackTrace) {
      // Step 5: Log errors with stack trace for debugging
      print('DEBUG: Error creating cart: $e');
      print('DEBUG: Stack trace: $stackTrace');
      throw CartRepositoryException('Failed to create cart: $e');
    }
  }

  /// Adds items to an existing cart specified by cartId.
  /// Takes a list of CartLineInput objects specifying product variants and quantities.
  /// Includes debugging logs for input, API call, and response.
  Future<Cart> addItemsToCart({
    required String cartId,
    required List<CartLineUpdateInput> cartLineInputs,
    bool reverse = false,
  }) async {
    try {
      // Step 1: Log input parameters
      print('DEBUG: Preparing to add items to cart with ID: $cartId');

      // Step 2: Call ShopifyCart.addLineItemsToCart
      print('DEBUG: Sending cartLinesAdd mutation to Shopify API...');
      final Cart updatedCart = await _shopifyCart.addLineItemsToCart(
        cartId: cartId,
        cartLineInputs: cartLineInputs,
        reverse: reverse,
      );

      // Step 3: Log the response
      if (updatedCart.id == null) {
        print('DEBUG: Warning - Updated cart has no ID');
        throw CartRepositoryException('Updated cart is invalid: missing ID');
      }
      print('DEBUG: Items added to cart successfully!');
      print('DEBUG: Updated cart ID: ${updatedCart.id}');
      print(
        'DEBUG: Updated cart details - lines: ${updatedCart.lines.length}, total: ${updatedCart.cost?.totalAmount?.amount ?? 0.0}',
      );

      return updatedCart;
    } catch (e, stackTrace) {
      // Step 4: Log errors with stack trace for debugging
      print('DEBUG: Error adding items to cart: $e');
      print('DEBUG: Stack trace: $stackTrace');
      throw CartRepositoryException('Failed to add items to cart: $e');
    }
  }

  /// Retrieves a cart by its ID from the Shopify API.
  /// Returns the cart data or throws an exception if not found.
  /// Includes debugging logs for input, API call, and response.
  Future<Cart> getCartById(String cartId) async {
    try {
      // Step 1: Log input parameters
      print('DEBUG: Preparing to fetch cart with ID: $cartId');

      // Step 2: Call ShopifyCart.getCart
      print('DEBUG: Sending cart query to Shopify API...');
      final Cart? cart = await _shopifyCart.getCartById(cartId);

      // Step 3: Log the response
      if (cart!.id == null) {
        print('DEBUG: Warning - Retrieved cart has no ID');
        throw CartRepositoryException('Retrieved cart is invalid: missing ID');
      }
      print('DEBUG: Cart retrieved successfully!');
      print('DEBUG: Cart ID: ${cart.id}');
      print(
        'DEBUG: Cart details - lines: ${cart.lines.length}, total: ${cart.cost?.totalAmount?.amount ?? 0.0}',
      );

      return cart;
    } catch (e, stackTrace) {
      // Step 4: Log errors with stack trace for debugging
      print('DEBUG: Error retrieving cart: $e');
      print('DEBUG: Stack trace: $stackTrace');
      throw CartRepositoryException('Failed to retrieve cart: $e');
    }
  }
}
