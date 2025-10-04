import 'dart:developer';

import 'package:dartz/dartz.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/products/model/product_failure.dart';

class ProductsRepository {
  // Singleton pattern for better performance
  static final ProductsRepository _instance = ProductsRepository._internal();
  factory ProductsRepository() => _instance;
  ProductsRepository._internal();

  // Simple in-memory cache to avoid repeated network calls
  List<Map<String, dynamic>>? _cachedCollectionsResult;
  DateTime? _cacheTimestamp;
  final Duration _cacheTtl = const Duration(minutes: 10);

  // Limit concurrent collection product fetches to avoid rate limits
  static const int _maxConcurrentRequests = 3;

  Future<Either<ProductFailure, List<Map<String, dynamic>>>> getProducts({
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Return cached result when valid and not forcing refresh
      if (!forceRefresh &&
          _cachedCollectionsResult != null &&
          _cacheTimestamp != null &&
          DateTime.now().difference(_cacheTimestamp!) < _cacheTtl) {
        return right(_cachedCollectionsResult!);
      }

      final shopifyStore = ShopifyStore.instance;

      // Fetch all collections
      final collections = await _fetchCollectionsOptimized();

      if (collections.isEmpty) {
        return left(NoProductsFailure());
      }

      // Process collections in limited-concurrency batches
      final List<Map<String, dynamic>> collectionResults = [];
      for (var i = 0; i < collections.length; i += _maxConcurrentRequests) {
        final batch = collections.skip(i).take(_maxConcurrentRequests).toList();
        final futures = batch.map(
          (collection) => _fetchAllCollectionProducts(collection, shopifyStore),
        );
        final results = await Future.wait(futures);
        for (final result in results) {
          if ((result['products'] as List).isNotEmpty) {
            collectionResults.add(result);
          }
        }
        // Small delay between batches to reduce chance of rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (collectionResults.isEmpty) {
        return left(NoProductsFailure());
      }

      // Cache results
      _cachedCollectionsResult = collectionResults;
      _cacheTimestamp = DateTime.now();

      return right(collectionResults);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }

  // Optimized collection fetching
  Future<List<Collection>> _fetchCollectionsOptimized() async {
    final shopifyStore = ShopifyStore.instance;

    try {
      return await shopifyStore.getAllCollections();
    } catch (e) {
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
      final List<Map<String, dynamic>> allProducts = [];
      String? cursor;
      int attempts = 0;
      const int maxAttempts = 100;

      while (attempts < maxAttempts) {
        attempts++;

        try {
          // Fetch products with cursor-based pagination
          final products = await shopifyStore
              .getXProductsAfterCursorWithinCollection(
                collection.id,
                250,
                startCursor: cursor,
              );

          if (products == null || products.isEmpty) {
            break;
          }

          final productList = products.map((product) {
            final gid = product.id;
            final id = int.tryParse(gid.split('/').last) ?? 0;
            final price = product.price;

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

          // If fewer than page size, we've reached the end
          if (productList.length < 250) {
            break;
          }

          // Update cursor
          if (products.isNotEmpty) {
            cursor = products.last.id;
          }

          await Future.delayed(const Duration(milliseconds: 50));
        } catch (_) {
          // Stop on batch error to avoid infinite loops; return what we have
          break;
        }
      }

      return {
        'collectionId': collectionId,
        'collectionName': collection.title,
        'products': allProducts,
        'totalCount': allProducts.length,
      };
    } catch (_) {
      return {
        'collectionId': collectionId,
        'collectionName': collection.title,
        'products': <Map<String, dynamic>>[],
        'totalCount': 0,
      };
    }
  }

  // Load more products - kept for compatibility
  Future<Either<ProductFailure, List<Map<String, dynamic>>>> loadMoreProducts({
    int page = 1,
    int limit = 20,
  }) async {
    return await getProducts(forceRefresh: true);
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
        final price = product.price;

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
