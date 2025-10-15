import 'package:shopify_flutter/shopify_flutter.dart';

class ShipmentRepository {
  Future<bool> validateMerchandiseId(String merchandiseId) async {
    try {
      final shopifyCustom = ShopifyCustom.instance;

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
      if (node == null || node['__typename'] != 'ProductVariant') return false;

      final product = node['product'];
      if (product == null) return false;

      final variants = product['variants']['edges'] as List<dynamic>?;
      return variants?.any((edge) => edge['node']['id'] == merchandiseId) ??
          false;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>> createCheckout({
    required String email,
    required String cartId,
    required String customerAccessToken,
    required List<CartLineInput> lineItems,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      if (lineItems.isEmpty)
        throw Exception('Cannot create checkout: No items in cart');

      // Validate merchandise IDs
      for (final item in lineItems) {
        if (item.merchandiseId.isEmpty) {
          throw Exception('Invalid merchandise ID found in cart items');
        }
      }

      final shopifyCart = ShopifyCart.instance;
      final shopifyCustom = ShopifyCustom.instance;

      // Create cart with line items and buyer identity
      final cartInput = CartInput(
        lines: lineItems,
        buyerIdentity: CartBuyerIdentityInput(
          email: email,
          customerAccessToken: customerAccessToken.isNotEmpty
              ? customerAccessToken
              : null,
        ),
      );

      Cart? newCart;
      try {
        newCart = await shopifyCart.createCart(cartInput);
      } catch (cartError) {
        // Try creating cart without customer access token as fallback
        try {
          final fallbackCartInput = CartInput(
            lines: lineItems,
            buyerIdentity: CartBuyerIdentityInput(email: email),
          );
          newCart = await shopifyCart.createCart(fallbackCartInput);
        } catch (fallbackError) {
          throw Exception('Failed to create cart: ${cartError.toString()}');
        }
      }

      if (newCart == null || newCart.id.isEmpty) {
        throw Exception(
          'Failed to create new cart: Shopify returned cart without ID',
        );
      }

      // Fetch cart with checkoutUrl and total amount
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
            lines(first: 100) {
              edges {
                node {
                  id
                  quantity
                  merchandise {
                    ... on ProductVariant {
                      id
                      title
                    }
                  }
                }
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
        throw Exception('Cart query failed: No response data from GraphQL');
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

  /// Updates customer phone number before checkout
  Future<bool> updateCustomerPhone({
    required String customerAccessToken,
    required String phone,
  }) async {
    try {
      final shopifyCustom = ShopifyCustom.instance;

      // Get customer ID
      const customerQuery = r'''
        query getCustomer($customerAccessToken: String!) {
          customer(customerAccessToken: $customerAccessToken) {
            id
            phone
          }
        }
      ''';

      final customerResult = await shopifyCustom.customQuery(
        gqlQuery: customerQuery,
        variables: {'customerAccessToken': customerAccessToken},
      );

      final customer = customerResult?['customer'];
      if (customer == null) return false;

      final customerId = customer['id'] as String?;
      if (customerId == null) return false;

      // Update customer phone number
      const updateMutation = r'''
        mutation customerUpdate($customerAccessToken: String!, $customer: CustomerUpdateInput!) {
          customerUpdate(customerAccessToken: $customerAccessToken, customer: $customer) {
            customer {
              id
              phone
            }
            userErrors {
              field
              message
            }
          }
        }
      ''';

      final updateResult = await shopifyCustom.customQuery(
        gqlQuery: updateMutation,
        variables: {
          'customerAccessToken': customerAccessToken,
          'customer': {'phone': phone},
        },
      );

      final customerUpdate = updateResult?['customerUpdate'];
      if (customerUpdate == null) return false;

      final userErrors = customerUpdate['userErrors'] as List<dynamic>?;
      if (userErrors != null && userErrors.isNotEmpty) return false;

      return customerUpdate['customer'] != null;
    } catch (e) {
      return false;
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
      if (node == null || node['__typename'] != 'Checkout') return false;

      return node['completedAt'] != null;
    } catch (e) {
      return false;
    }
  }
}
