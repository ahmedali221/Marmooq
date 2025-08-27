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
        print('Error validating merchandise ID: Variant not found or invalid');
        return false;
      }

      final product = node['product'];
      if (product == null) {
        print('Error validating merchandise ID: No associated product');
        return false;
      }

      // Check if the variant exists in the product's variants
      final variants = product['variants']['edges'] as List<dynamic>?;
      final variantExists =
          variants?.any((edge) => edge['node']['id'] == merchandiseId) ?? false;

      return variantExists;
    } catch (e) {
      print('Error validating merchandise ID: $e');
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

      // Debug: Log input data
      print('Debug: Creating cart with input:');
      print('  email: $email');
      print('  customerAccessToken: $customerAccessToken');
      print(
        '  lineItems: ${lineItems.map((item) => 'merchandiseId: ${item.merchandiseId}, quantity: ${item.quantity}').join(', ')}',
      );

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

      // Debug: Log created cart details
      print(
        'Debug: Created cart with ID: ${newCart.id}, lines: ${newCart.lines?.map((line) => 'merchandiseId: ${line.merchandise?.id}, quantity: ${line.quantity}').join(', ')}',
      );

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

      // Debug: Log full cart query response
      print('Debug: Cart query response: $cartResult');

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
      print('Error creating checkout: $e');
      throw Exception('Failed to create checkout: $e');
    }
  }
}
