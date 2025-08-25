import 'package:shopify_flutter/models/src/cart/cart.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_input/cart_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_input/cart_line_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_buyer_identity_input/cart_buyer_identity_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';
import 'package:shopify_flutter/shopify/src/shopify_cart.dart';
import '../model/cart_Item.dart';

class CartRepository {
  final ShopifyCart _shopifyCart = ShopifyCart.instance;

  // Create a new cart
  Future<Cart> createCart({String? note, List<String>? discountCodes}) async {
    try {
      final cartInput = CartInput(
        lines: [],
        attributes: [],
        note: note ?? '',
        discountCodes: discountCodes ?? [],
      );
      return await _shopifyCart.createCart(cartInput);
    } catch (e) {
      throw CartRepositoryException('Failed to create cart: $e');
    }
  }

  // Get cart by ID
  Future<Cart> getCartById(String cartId, {bool reverse = false}) async {
    try {
      final cart = await _shopifyCart.getCartById(cartId, reverse: reverse);
      if (cart == null) {
        throw CartRepositoryException('Cart not found');
      }
      return cart;
    } catch (e) {
      throw CartRepositoryException('Failed to get cart: $e');
    }
  }

  // Add items to cart
  Future<Cart> addItemsToCart({
    required String cartId,
    required List<CartLineInput> cartLineInputs,
    bool reverse = false,
  }) async {
    try {
      return await _shopifyCart.addLineItemsToCart(
        cartId: cartId,
        cartLineInputs: cartLineInputs
            .map(
              (input) => CartLineUpdateInput(
                quantity: input.quantity,
                merchandiseId: input.merchandiseId,
              ),
            )
            .toList(),
        reverse: reverse,
      );
    } catch (e) {
      throw CartRepositoryException('Failed to add items to cart: $e');
    }
  }

  // Update items in cart
  Future<Cart> updateItemsInCart({
    required String cartId,
    required List<CartLineUpdateInput> cartLineInputs,
    bool reverse = false,
  }) async {
    try {
      return await _shopifyCart.updateLineItemsInCart(
        cartId: cartId,
        cartLineInputs: cartLineInputs,
        reverse: reverse,
      );
    } catch (e) {
      throw CartRepositoryException('Failed to update items in cart: $e');
    }
  }

  // Remove items from cart
  Future<Cart> removeItemsFromCart({
    required String cartId,
    required List<String> lineIds,
    bool reverse = false,
  }) async {
    try {
      return await _shopifyCart.removeLineItemsFromCart(
        cartId: cartId,
        lineIds: lineIds,
        reverse: reverse,
      );
    } catch (e) {
      throw CartRepositoryException('Failed to remove items from cart: $e');
    }
  }

  // Update cart note
  Future<Cart> updateCartNote({
    required String cartId,
    required String note,
    bool reverse = false,
  }) async {
    try {
      return await _shopifyCart.updateNoteInCart(
        cartId: cartId,
        note: note,
        reverse: reverse,
      );
    } catch (e) {
      throw CartRepositoryException('Failed to update cart note: $e');
    }
  }

  // Update discount codes
  Future<Cart> updateDiscountCodes({
    required String cartId,
    required List<String> discountCodes,
    bool reverse = false,
  }) async {
    try {
      return await _shopifyCart.updateCartDiscountCodes(
        cartId: cartId,
        discountCodes: discountCodes,
        reverse: reverse,
      );
    } catch (e) {
      throw CartRepositoryException('Failed to update discount codes: $e');
    }
  }

  // Update buyer identity for checkout
  Future<Cart> updateBuyerIdentity({
    required String cartId,
    required CartBuyerIdentityInput buyerIdentity,
    bool reverse = false,
  }) async {
    try {
      return await _shopifyCart.updateBuyerIdentityInCart(
        cartId: cartId,
        buyerIdentity: buyerIdentity,
        reverse: reverse,
      );
    } catch (e) {
      throw CartRepositoryException('Failed to update buyer identity: $e');
    }
  }

  // Helper method to map Cart to CartItems with proper price calculation
  List<CartItem> mapToCartItems(Cart cart) {
    return cart.lines.map((line) {
      // Extract price from merchandise (variant)
      double price = 0.0;
      String title = 'Product';

      // In a real implementation, you would fetch product details
      // For now, we'll use the line's merchandise information
      if (line.merchandise != null) {
        // Access price from the merchandise/variant
        price = line.merchandise!.price?.amount ?? 0.0;
        title = line.merchandise!.product?.title ?? 'Product';
      }

      return CartItem(
        id: line.id!,
        variantId: line.merchandise!.id,
        title: title,
        quantity: line.quantity!,
        price: price,
      );
    }).toList();
  }

  // Calculate cart totals
  CartTotals calculateCartTotals(Cart cart) {
    double subtotal = 0.0;
    double totalTax = 0.0;
    double totalDiscount = 0.0;

    // Calculate subtotal from line items
    for (final line in cart.lines) {
      if (line.merchandise?.price?.amount != null) {
        subtotal += (line.merchandise!.price!.amount * line.quantity!);
      }
    }

    // Get tax and discount information from cart cost
    if (cart.cost != null) {
      totalTax = cart.cost!.totalTaxAmount?.amount ?? 0.0;
      totalDiscount =
          subtotal - (cart.cost!.subtotalAmount?.amount ?? subtotal);
    }

    final total = cart.cost?.totalAmount?.amount ?? subtotal;

    return CartTotals(
      subtotal: subtotal,
      totalTax: totalTax,
      totalDiscount: totalDiscount,
      total: total,
    );
  }

  // Validate cart for checkout
  Future<bool> validateCartForCheckout(String cartId) async {
    try {
      final cart = await getCartById(cartId);

      // Check if cart has items
      if (cart.lines.isEmpty) {
        throw CartRepositoryException('Cart is empty');
      }

      // Check if all items are available
      for (final line in cart.lines) {
        if (line.merchandise?.availableForSale != true) {
          throw CartRepositoryException('Some items are no longer available');
        }
      }

      return true;
    } catch (e) {
      throw CartRepositoryException('Cart validation failed: $e');
    }
  }
}

// Custom exception class for cart operations
class CartRepositoryException implements Exception {
  final String message;
  CartRepositoryException(this.message);

  @override
  String toString() => 'CartRepositoryException: $message';
}

// Helper class for cart totals
class CartTotals {
  final double subtotal;
  final double totalTax;
  final double totalDiscount;
  final double total;

  CartTotals({
    required this.subtotal,
    required this.totalTax,
    required this.totalDiscount,
    required this.total,
  });
}
