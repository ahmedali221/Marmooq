import 'package:shopify_flutter/models/src/cart/cart.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_input/cart_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_input/cart_line_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';
import 'package:shopify_flutter/shopify/src/shopify_cart.dart';
import 'package:marmooq/core/services/security_service.dart';

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
  Future<Cart> createCart({
    String? note,
    List<String>? discountCodes,
    List<AttributeInput>? attributes,
  }) async {
    try {
      // Step 2: Create CartInput with empty lines and no buyerIdentity
      final cartInput = CartInput(
        lines: [], // No initial line items
        attributes: attributes ?? [],
        note: note ?? '',
        discountCodes: discountCodes ?? [],
        buyerIdentity:
            null, // Explicitly set to null for no customer association
      );

      // Step 3: Call ShopifyCart.createCart
      final Cart createdCart = await _shopifyCart.createCart(cartInput);

      // Step 4: Validate response
      if (createdCart.id == null) {
        throw CartRepositoryException('Created cart is invalid: missing ID');
      }

      // Store cart ID securely
      if (createdCart.id != null) {
        await SecurityService.storeCartId(createdCart.id!);
      }

      return createdCart;
    } catch (e) {
      throw CartRepositoryException('Failed to create cart: $e');
    }
  }

  /// Adds items to an existing cart specified by cartId.
  /// Takes a list of CartLineInput objects specifying product variants and quantities.
  Future<Cart> addItemsToCart({
    required String cartId,
    required List<CartLineUpdateInput> cartLineInputs,
    bool reverse = false,
  }) async {
    try {
      // Step 2: Call ShopifyCart.addLineItemsToCart
      final Cart updatedCart = await _shopifyCart.addLineItemsToCart(
        cartId: cartId,
        cartLineInputs: cartLineInputs,
        reverse: reverse,
      );

      // Step 3: Validate response
      if (updatedCart.id == null) {
        throw CartRepositoryException('Updated cart is invalid: missing ID');
      }

      return updatedCart;
    } catch (e) {
      throw CartRepositoryException('Failed to add items to cart: $e');
    }
  }

  /// Retrieves a cart by its ID from the Shopify API.
  /// Returns the cart data or throws an exception if not found.
  Future<Cart> getCartById(String cartId) async {
    try {
      // Step 2: Call ShopifyCart.getCart
      final Cart? cart = await _shopifyCart.getCartById(cartId);

      // Step 3: Validate response
      if (cart!.id == null) {
        throw CartRepositoryException('Retrieved cart is invalid: missing ID');
      }

      return cart;
    } catch (e) {
      throw CartRepositoryException('Failed to retrieve cart: $e');
    }
  }

  /// Clears all items from a cart by removing all line items.
  /// This effectively empties the cart while keeping the cart instance.
  Future<Cart> clearCart(String cartId) async {
    try {
      // Step 2: Get current cart to extract line item IDs
      final Cart currentCart = await getCartById(cartId);
      if (currentCart.lines.isEmpty) {
        return currentCart;
      }

      // Step 3: Extract all line item IDs for removal
      final List<String> lineIds = currentCart.lines
          .where((line) => line.id != null)
          .map((line) => line.id!)
          .toList();

      if (lineIds.isEmpty) {
        return currentCart;
      }

      // Step 4: Call ShopifyCart.removeLineItemsFromCart to clear all items
      final Cart clearedCart = await _shopifyCart.removeLineItemsFromCart(
        cartId: cartId,
        lineIds: lineIds,
        reverse: false,
      );

      // Step 5: Validate response
      if (clearedCart.id == null) {
        throw CartRepositoryException('Cleared cart is invalid: missing ID');
      }

      // Step 6: Clear the stored cart ID from secure storage
      try {
        await SecurityService.clearCartId();
      } catch (e) {
        // Don't throw error for storage clearing failure
      }

      return clearedCart;
    } catch (e) {
      throw CartRepositoryException('Failed to clear cart: $e');
    }
  }

  /// Clears the current cart and creates a new empty cart for future use.
  /// This is useful after order completion to start fresh.
  Future<Cart> clearCartAndCreateNew() async {
    try {
      // Step 2: Get current cart ID from secure storage
      final String? currentCartId = await SecurityService.getCartId();
      if (currentCartId == null) {
        return await createCart();
      }

      // Step 3: Clear the current cart
      await clearCart(currentCartId);

      // Step 4: Create a new empty cart
      final Cart newCart = await createCart();

      return newCart;
    } catch (e) {
      throw CartRepositoryException(
        'Failed to clear cart and create new one: $e',
      );
    }
  }

  /// Clears the current cart and creates a new empty cart for future use.
  /// This method also notifies that the cart has been cleared.
  /// This is useful after order completion to start fresh.
  Future<Cart> clearCartAndCreateNewWithNotification() async {
    try {
      // Step 2: Get current cart ID from secure storage
      final String? currentCartId = await SecurityService.getCartId();
      if (currentCartId == null) {
        return await createCart();
      }

      // Step 3: Clear the current cart
      await clearCart(currentCartId);

      // Step 4: Create a new empty cart
      final Cart newCart = await createCart();

      // Step 5: Note: This method doesn't emit events directly
      // The calling code should emit CartClearedEvent to update UI

      return newCart;
    } catch (e) {
      throw CartRepositoryException(
        'Failed to clear cart and create new one with notification: $e',
      );
    }
  }

  /// Updates line items in an existing cart specified by cartId.
  /// Takes a list of CartLineUpdateInput objects specifying line IDs and new quantities.
  Future<Cart> updateLineItemsInCart({
    required String cartId,
    required List<CartLineUpdateInput> cartLineInputs,
    bool reverse = false,
  }) async {
    try {
      // Step 2: Call ShopifyCart.updateLineItemsInCart
      final Cart updatedCart = await _shopifyCart.updateLineItemsInCart(
        cartId: cartId,
        cartLineInputs: cartLineInputs,
        reverse: reverse,
      );

      // Step 3: Validate response
      if (updatedCart.id == null) {
        throw CartRepositoryException('Updated cart is invalid: missing ID');
      }

      return updatedCart;
    } catch (e) {
      throw CartRepositoryException('Failed to update line items in cart: $e');
    }
  }
}
