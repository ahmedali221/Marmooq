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
}
