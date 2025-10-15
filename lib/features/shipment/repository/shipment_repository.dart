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
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      // Enhanced validation and debugging
      print('[DEBUG] Starting checkout creation with:');
      print('[DEBUG] Email: $email');
      print('[DEBUG] First Name: $firstName');
      print('[DEBUG] Last Name: $lastName');
      print('[DEBUG] Phone: $phone');
      print(
        '[DEBUG] Customer Access Token: ${customerAccessToken.isNotEmpty ? 'Present' : 'Empty'}',
      );
      print('[DEBUG] Line Items Count: ${lineItems.length}');

      // Validate line items
      if (lineItems.isEmpty) {
        throw Exception('Cannot create checkout: No items in cart');
      }

      // Validate merchandise IDs
      for (final item in lineItems) {
        if (item.merchandiseId.isEmpty) {
          throw Exception('Invalid merchandise ID found in cart items');
        }
        print('[DEBUG] Line Item: ${item.merchandiseId} x${item.quantity}');
      }

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

      print('[DEBUG] Creating cart with Shopify...');
      final newCart = await shopifyCart.createCart(cartInput);
      if (newCart.id.isEmpty) {
        throw Exception(
          'Failed to create new cart: Shopify returned cart without ID',
        );
      }

      print('[DEBUG] Cart created successfully with ID: ${newCart.id}');

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

      print('[DEBUG] Fetching cart details with GraphQL...');
      final cartResult = await shopifyCustom.customQuery(
        gqlQuery: cartQuery,
        variables: {'id': newCart.id},
      );

      print('[DEBUG] GraphQL Response: $cartResult');

      final cartData = cartResult?['cart'];
      if (cartData == null) {
        throw Exception('Cart query failed: No response data from GraphQL');
      }

      final checkoutUrl = cartData['checkoutUrl'] as String?;
      final totalAmount = cartData['cost']?['totalAmount']?['amount']
          ?.toString();

      print('[DEBUG] Checkout URL: $checkoutUrl');
      print('[DEBUG] Total Amount: $totalAmount');

      if (checkoutUrl == null || totalAmount == null) {
        throw Exception(
          'Cart query failed: Missing checkoutUrl or totalAmount. '
          'Checkout URL: $checkoutUrl, Total Amount: $totalAmount',
        );
      }

      print('[DEBUG] Checkout created successfully!');
      return {
        'id': cartData['id'],
        'webUrl': checkoutUrl,
        'totalPrice': totalAmount,
      };
    } catch (e) {
      print('[ERROR] Checkout creation failed: $e');
      print('[ERROR] Stack trace: ${StackTrace.current}');
      throw Exception('Failed to create checkout: $e');
    }
  }

  /// Updates customer phone number before checkout
  Future<bool> updateCustomerPhone({
    required String customerAccessToken,
    required String phone,
  }) async {
    try {
      print('[DEBUG] Updating customer phone number...');
      print('[DEBUG] Phone: $phone');

      final shopifyCustom = ShopifyCustom.instance;

      // First, get the customer ID using the access token
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
      if (customer == null) {
        print('[ERROR] Could not fetch customer data');
        return false;
      }

      final customerId = customer['id'] as String?;
      if (customerId == null) {
        print('[ERROR] Customer ID not found');
        return false;
      }

      print('[DEBUG] Customer ID: $customerId');
      print('[DEBUG] Current phone: ${customer['phone']}');

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
      if (customerUpdate == null) {
        print('[ERROR] Customer update failed: No response');
        return false;
      }

      final userErrors = customerUpdate['userErrors'] as List<dynamic>?;
      if (userErrors != null && userErrors.isNotEmpty) {
        print('[ERROR] Customer update errors: $userErrors');
        return false;
      }

      final updatedCustomer = customerUpdate['customer'];
      if (updatedCustomer == null) {
        print('[ERROR] Customer update failed: No customer data returned');
        return false;
      }

      print(
        '[DEBUG] Customer phone updated successfully: ${updatedCustomer['phone']}',
      );
      return true;
    } catch (e) {
      print('[ERROR] Failed to update customer phone: $e');
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
      if (node == null || node['__typename'] != 'Checkout') {
        return false;
      }

      return node['completedAt'] != null;
    } catch (e) {
      return false;
    }
  }
}
