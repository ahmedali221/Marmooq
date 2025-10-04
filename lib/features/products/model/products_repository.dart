import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/products/model/product_failure.dart';

class ProductsRepository {
  // Singleton pattern for better performance
  static final ProductsRepository _instance = ProductsRepository._internal();
  factory ProductsRepository() => _instance;
  ProductsRepository._internal();

  Future<Either<ProductFailure, List<Map<String, dynamic>>>> getProducts({
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      log('Fetching ALL products data from API');

      final shopifyStore = ShopifyStore.instance;

      // Fetch all collections
      final collections = await _fetchCollectionsOptimized();

      if (collections.isEmpty) {
        return left(NoProductsFailure());
      }

      log('Fetched ${collections.length} collections from API');

      // Process all collections to get ALL products
      final List<Map<String, dynamic>> collectionResults = [];

      for (final collection in collections) {
        final result = await _fetchAllCollectionProducts(
          collection,
          shopifyStore,
        );
        if ((result['products'] as List).isNotEmpty) {
          collectionResults.add(result);
        }

        // Small delay to prevent rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (collectionResults.isEmpty) {
        return left(NoProductsFailure());
      }

      log(
        'Successfully fetched products for ${collectionResults.length} collections',
      );
      return right(collectionResults);
    } catch (e) {
      log('Error fetching products: $e');
      return left(ServerFailure(e.toString()));
    }
  }

  // Optimized collection fetching
  Future<List<Collection>> _fetchCollectionsOptimized() async {
    final shopifyStore = ShopifyStore.instance;

    try {
      // Use getNProducts with BEST_SELLING sort for better performance
      return await shopifyStore.getAllCollections();
    } catch (e) {
      log('Error fetching collections: $e');
      rethrow;
    }
  }

  // Fetch ALL products from a collection without pagination limits
  Future<Map<String, dynamic>> _fetchAllCollectionProducts(
    Collection collection,
    ShopifyStore shopifyStore,
  ) async {
    final collectionId = collection.id.split('/').last;

    try {
      log('Fetching ALL products for collection: ${collection.title}');

      final List<Map<String, dynamic>> allProducts = [];
      String? cursor;
      int totalFetched = 0;
      int attempts = 0;
      const int maxAttempts =
          100; // Increased limit to handle large collections

      while (attempts < maxAttempts) {
        attempts++;

        try {
          // Fetch products with cursor-based pagination - no limit on batch size
          final products = await shopifyStore
              .getXProductsAfterCursorWithinCollection(
                collection.id,
                250, // Maximum allowed by Shopify API
                startCursor: cursor,
              );

          if (products == null || products.isEmpty) {
            log('No more products found for collection ${collection.title}');
            break;
          }

          // Process products
          final productList = products.map((product) {
            final gid = product.id;
            final id = int.tryParse(gid.split('/').last) ?? 0;
            final price = product.price;

            // Optimize image processing - only take first 3 images
            final images = product.images
                .take(3)
                .map((image) => image.originalSrc)
                .toList();

            return {
              'id': id,
              'name': product.title,
              'description': product.description,
              'price': price,
              'images': images,
              'variantId': product.productVariants.isNotEmpty
                  ? product.productVariants.first.id
                  : '',
            };
          }).toList();

          allProducts.addAll(productList);
          totalFetched += productList.length;

          log(
            'Fetched ${productList.length} products for ${collection.title} (total: $totalFetched)',
          );

          // Check if we got fewer products than requested (end of collection)
          if (productList.length < 250) {
            log('Reached end of collection ${collection.title}');
            break;
          }

          // Update cursor for next batch
          if (products.isNotEmpty) {
            cursor = products.last.id;
          }

          // Small delay to prevent rate limiting
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          log('Error fetching batch for collection ${collection.title}: $e');
          break;
        }
      }

      log(
        'Successfully fetched ${allProducts.length} products for collection ${collection.title}',
      );

      return {
        'collectionId': collectionId,
        'collectionName': collection.title,
        'products': allProducts,
        'totalCount': allProducts.length,
      };
    } catch (e) {
      log('Error fetching products for collection ${collection.title}: $e');
      return {
        'collectionId': collectionId,
        'collectionName': collection.title,
        'products': <Map<String, dynamic>>[],
        'totalCount': 0,
      };
    }
  }

  // Load more products - now just calls getProducts since we fetch all at once
  Future<Either<ProductFailure, List<Map<String, dynamic>>>> loadMoreProducts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Since we now fetch all products at once, this method just calls getProducts
      return await getProducts(forceRefresh: true);
    } catch (e) {
      log('Error loading more products: $e');
      return left(ServerFailure(e.toString()));
    }
  }

  // Search products
  Future<Either<ProductFailure, List<Map<String, dynamic>>>> searchProducts(
    String query, {
    int limit = 15,
    String? startCursor,
  }) async {
    try {
      final shopifyStore = ShopifyStore.instance;

      final products = await shopifyStore.searchProducts(
        query,
        limit: limit,
        startCursor: startCursor,
        sortKey: SearchSortKeys.RELEVANCE,
      );

      if (products == null || products.isEmpty) {
        return left(NoProductsFailure());
      }

      final productList = products.map((product) {
        final gid = product.id;
        final id = int.tryParse(gid.split('/').last) ?? 0;
        final price = product.price; // Price is already in KWD

        final images = product.images
            .take(3)
            .map((image) => image.originalSrc)
            .toList();

        return {
          'id': id,
          'name': product.title,
          'description': product.description,
          'price': price,
          'images': images,
          'variantId': product.productVariants.isNotEmpty
              ? product.productVariants.first.id
              : '',
        };
      }).toList();

      return right([
        {
          'collectionId': 'search_results',
          'collectionName': 'نتائج البحث',
          'products': productList,
          'totalCount': productList.length,
        },
      ]);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
