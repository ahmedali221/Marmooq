import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/features/products/model/product_failure.dart';

class ProductsRepository {
  // USD to KWD conversion rate (approximate)
  static const double _usdToKwdRate = 0.31;

  Future<Either<ProductFailure, List<Map<String, dynamic>>>>
  getProducts() async {
    try {
      final shopifyStore = ShopifyStore.instance;
      final collections = await shopifyStore.getAllCollections();

      if (collections.isEmpty) {
        return left(NoProductsFailure());
      }
      log(
        "Fetched Collections are : "
        "$collections",
      );
      final productFutures = collections.map(
        (collection) => shopifyStore
            .getAllProductsFromCollectionById(collection.id)
            .then((products) {
              final productList = products.map((product) {
                final gid = product.id;
                final id = int.tryParse(gid.split('/').last) ?? 0;
                final usdPrice = product.price;
                // Convert USD to KWD
                final kwdPrice = usdPrice * _usdToKwdRate;

                final images = product.images
                    .map((image) => image.originalSrc)
                    .toList();

                return {
                  'id': id,
                  'name': product.title,
                  'description': product.description,
                  'price': kwdPrice,
                  'images': images,
                  'variantId': product.productVariants.first.id,
                };
              }).toList();

              return {
                'collectionId': collection.id.split('/').last,
                'collectionName': collection.title,
                'products': productList,
              };
            }),
      );

      final collectionResults = await Future.wait(productFutures);

      final collectionsWithProducts = collectionResults
          .where((result) => (result['products'] as List).isNotEmpty)
          .toList();

      if (collectionsWithProducts.isEmpty) {
        return left(NoProductsFailure());
      }

      return right(collectionsWithProducts);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
