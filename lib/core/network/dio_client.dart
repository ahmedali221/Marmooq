import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Dio client configuration with a singleton pattern and private constructor.
class DioClient {
  static final DioClient _instance = DioClient._internal();
  final Dio _storefrontDio;

  /// Private constructor to prevent external instantiation.
  DioClient._internal()
    : _storefrontDio = Dio(
        BaseOptions(
          baseUrl: 'https://fagk1b-a1.myshopify.com/api/2025-07/',
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'X-Shopify-Storefront-Access-Token':
                dotenv.env['SHOPIFY_STOREFRONT_TOKEN'],
          },
        ),
      ) {
    _storefrontDio.interceptors.add(
      InterceptorsWrapper(
        onError: (DioException e, ErrorInterceptorHandler handler) {
          // Handle storefront-specific errors
          return handler.next(e);
        },
      ),
    );
  }

  /// Factory constructor to return the singleton instance.
  factory DioClient() => _instance;

  /// Getter for the Storefront API Dio instance.
  Dio get storefrontDio => _storefrontDio;

  /// Static getter for the singleton instance.
  static DioClient get instance => _instance;

  /// Helper method for Storefront API GET requests.
  Future<Response> get(String path, {Options? options}) async {
    return await _storefrontDio.get(path, options: options);
  }

  /// Helper method for Storefront API POST requests.
  Future<Response> post(String path, {dynamic data, Options? options}) async {
    return await _storefrontDio.post(path, data: data, options: options);
  }

  /// Helper method for Storefront API GraphQL requests.
  Future<Response> storefrontGraphQL(
    String query, {
    Map<String, dynamic>? variables,
  }) async {
    return await _storefrontDio.post(
      'graphql.json',
      data: {'query': query, if (variables != null) 'variables': variables},
    );
  }
}
