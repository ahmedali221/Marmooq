import 'package:shopify_flutter/shopify_flutter.dart';

class ShipmentRepository {
  Future<bool> validateMerchandiseId(String merchandiseId) async {
    try {
      final shopifyCustom = ShopifyCustom.instance;

      // GraphQL query to fetch the product by variant ID
      const variantQuery = r'''
        query getProductByVariant($id: ID!) {
          node(id: $id) {
            ... on ProductVariant {
              id
              product {
                id
                variants(first: 100) {
                  edges {
                    node {
                      id
                    }
                  }
                }
              }
            }
          }
        }
      ''';

      final result = await shopifyCustom.customQuery(
        gqlQuery: variantQuery,
        variables: {'id': merchandiseId},
      );

      final node = result?['node'];
      if (node == null || node['__typename'] != 'ProductVariant') {
        return false;
      }

      final product = node['product'];
      if (product == null) {
        return false;
      }

      // Check if the variant exists in the product's variants
      final variants = product['variants']['edges'] as List<dynamic>?;
      final variantExists =
          variants?.any((edge) => edge['node']['id'] == merchandiseId) ?? false;

      return variantExists;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> createCheckout({
    required String email,
    required String cartId, // Kept for compatibility, but unused
    required String customerAccessToken,
    required List<CartLineInput> lineItems,
  }) async {
    try {
      final shopifyCart = ShopifyCart.instance;
      final shopifyCustom = ShopifyCustom.instance;

      // Create a new cart with the provided line items and buyer identity
      final cartInput = CartInput(
        lines: lineItems,
        buyerIdentity: CartBuyerIdentityInput(
          email: email,
          customerAccessToken: customerAccessToken.isNotEmpty
              ? customerAccessToken
              : null,
        ),
      );

      final newCart = await shopifyCart.createCart(cartInput);
      if (newCart == null) {
        throw Exception('Failed to create new cart');
      }

      // Fetch cart with checkoutUrl and cost.totalAmount using a custom query
      const cartQuery = r'''
        query getCart($id: ID!) {
          cart(id: $id) {
            id
            checkoutUrl
            cost {
              totalAmount {
                amount
                currencyCode
              }
            }
          }
        }
      ''';

      final cartResult = await shopifyCustom.customQuery(
        gqlQuery: cartQuery,
        variables: {'id': newCart.id},
      );

      final cartData = cartResult?['cart'];
      if (cartData == null) {
        throw Exception('Cart query failed: No response data');
      }

      final checkoutUrl = cartData['checkoutUrl'] as String?;
      final totalAmount = cartData['cost']?['totalAmount']?['amount']
          ?.toString();
      if (checkoutUrl == null || totalAmount == null) {
        throw Exception(
          'Cart query failed: Missing checkoutUrl or totalAmount',
        );
      }

      return {
        'id': cartData['id'],
        'webUrl': checkoutUrl,
        'totalPrice': totalAmount,
      };
    } catch (e) {
      throw Exception('Failed to create checkout: $e');
    }
  }

  Future<bool> isCheckoutCompleted(String checkoutId) async {
    try {
      final shopifyCustom = ShopifyCustom.instance;

      const checkoutQuery = r'''
        query getCheckoutStatus($id: ID!) {
          node(id: $id) {
            ... on Checkout {
              id
              completedAt
            }
          }
        }
      ''';

      final result = await shopifyCustom.customQuery(
        gqlQuery: checkoutQuery,
        variables: {'id': checkoutId},
      );

      final node = result?['node'];
      if (node == null || node['__typename'] != 'Checkout') {
        return false;
      }

      return node['completedAt'] != null;
    } catch (e) {
      return false;
    }
  }
}
