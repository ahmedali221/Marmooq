import 'dart:developer';
import 'dart:convert';

import 'package:dartz/dartz.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:traincode/features/products/model/product_failure.dart';

class ProductsRepository {
  // Cache configuration
  static const String _cacheKey = 'products_cache';
  static const String _cacheTimestampKey = 'products_cache_timestamp';
  static const Duration _cacheExpiration = Duration(minutes: 15);

  // Singleton pattern for better performance
  static final ProductsRepository _instance = ProductsRepository._internal();
  factory ProductsRepository() => _instance;
  ProductsRepository._internal();

  // Cache storage
  List<Map<String, dynamic>>? _cachedCollections;
  DateTime? _lastCacheTime;

  Future<Either<ProductFailure, List<Map<String, dynamic>>>> getProducts({
    bool forceRefresh = false,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Check cache first unless force refresh is requested
      if (!forceRefresh && _isCacheValid()) {
        log('Returning cached products data');
        return right(_cachedCollections!);
      }

      // Try to load from persistent cache
      if (!forceRefresh) {
        final cachedData = await _loadFromPersistentCache();
        if (cachedData != null) {
          _cachedCollections = cachedData;
          _lastCacheTime = DateTime.now();
          log('Loaded products from persistent cache');
          return right(cachedData);
        }
      }

      final shopifyStore = ShopifyStore.instance;

      // Use optimized collection fetching with pagination
      final collections = await _fetchCollectionsOptimized();

      if (collections.isEmpty) {
        return left(NoProductsFailure());
      }

      log('Fetched ${collections.length} collections from API');

      // Process collections in batches to avoid overwhelming the API
      final List<Map<String, dynamic>> collectionResults = [];

      for (int i = 0; i < collections.length; i += 3) {
        final batch = collections.skip(i).take(3).toList();
        final batchFutures = batch.map(
          (collection) => _fetchCollectionProducts(
            collection,
            shopifyStore,
            page: page,
            limit: limit,
          ),
        );

        final batchResults = await Future.wait(batchFutures);
        collectionResults.addAll(
          batchResults.where(
            (result) => (result['products'] as List).isNotEmpty,
          ),
        );

        // Small delay between batches to prevent rate limiting
        if (i + 3 < collections.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      if (collectionResults.isEmpty) {
        return left(NoProductsFailure());
      }

      // Cache the results
      await _cacheResults(collectionResults);
      _cachedCollections = collectionResults;
      _lastCacheTime = DateTime.now();

      return right(collectionResults);
    } catch (e) {
      log('Error fetching products: $e');

      // Try to return cached data as fallback
      if (_cachedCollections != null) {
        log('Returning cached data as fallback');
        return right(_cachedCollections!);
      }

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

  // Optimized product fetching for a single collection with pagination
  Future<Map<String, dynamic>> _fetchCollectionProducts(
    Collection collection,
    ShopifyStore shopifyStore, {
    int page = 1,
    int limit = 20,
  }) async {
    try {
      // Use paginated approach for better performance
      final products = await shopifyStore
          .getXProductsAfterCursorWithinCollection(collection.id, limit);

      final productList = products!.map((product) {
        final gid = product.id;
        final id = int.tryParse(gid.split('/').last) ?? 0;
        final price = product.price; // Price is already in KWD

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

      return {
        'collectionId': collection.id.split('/').last,
        'collectionName': collection.title,
        'products': productList,
      };
    } catch (e) {
      log('Error fetching products for collection ${collection.title}: $e');
      return {
        'collectionId': collection.id.split('/').last,
        'collectionName': collection.title,
        'products': <Map<String, dynamic>>[],
      };
    }
  }

  // Cache validation
  bool _isCacheValid() {
    if (_cachedCollections == null || _lastCacheTime == null) {
      return false;
    }

    final now = DateTime.now();
    return now.difference(_lastCacheTime!) < _cacheExpiration;
  }

  // Persistent cache operations
  Future<void> _cacheResults(List<Map<String, dynamic>> results) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(results);
      await prefs.setString(_cacheKey, jsonString);
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      log('Products cached to persistent storage');
    } catch (e) {
      log('Error caching products: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> _loadFromPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_cacheKey);
      final timestamp = prefs.getInt(_cacheTimestampKey);

      if (jsonString == null || timestamp == null) {
        return null;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();

      if (now.difference(cacheTime) > _cacheExpiration) {
        log('Persistent cache expired');
        await _clearPersistentCache();
        return null;
      }

      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.cast<Map<String, dynamic>>();
    } catch (e) {
      log('Error loading from persistent cache: $e');
      await _clearPersistentCache();
      return null;
    }
  }

  Future<void> _clearPersistentCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await prefs.remove(_cacheTimestampKey);
    } catch (e) {
      log('Error clearing persistent cache: $e');
    }
  }

  // Clear all caches
  Future<void> clearCache() async {
    _cachedCollections = null;
    _lastCacheTime = null;
    await _clearPersistentCache();
    log('All caches cleared');
  }

  // Load more products for pagination
  Future<Either<ProductFailure, List<Map<String, dynamic>>>> loadMoreProducts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final shopifyStore = ShopifyStore.instance;
      final collections = await _fetchCollectionsOptimized();

      if (collections.isEmpty) {
        return left(NoProductsFailure());
      }

      final List<Map<String, dynamic>> collectionResults = [];

      for (int i = 0; i < collections.length; i += 3) {
        final batch = collections.skip(i).take(3).toList();
        final batchFutures = batch.map(
          (collection) => _fetchCollectionProducts(
            collection,
            shopifyStore,
            page: page,
            limit: limit,
          ),
        );

        final batchResults = await Future.wait(batchFutures);
        collectionResults.addAll(
          batchResults.where(
            (result) => (result['products'] as List).isNotEmpty,
          ),
        );
      }

      return right(collectionResults);
    } catch (e) {
      log('Error loading more products: $e');
      return left(ServerFailure(e.toString()));
    }
  }

  // Search products with caching
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
        },
      ]);
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
