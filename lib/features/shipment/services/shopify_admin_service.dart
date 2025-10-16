import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

class ShopifyAdminService {
  static const String _storeUrl = 'fagk1b-a1.myshopify.com';
  static const String _apiVersion = '2024-07';

  final Dio _dio;
  late final String _adminToken;

  ShopifyAdminService() : _dio = Dio() {
    _adminToken = dotenv.env['ADMIN_ACCESS_TOKEN'] ?? '';
    print(
      '🔑 Admin token loaded: ${_adminToken.isNotEmpty ? "✅ Yes" : "❌ No"}',
    );
    print('🔑 Token length: ${_adminToken.length}');

    if (_adminToken.isEmpty) {
      throw Exception('Admin access token not found in environment');
    }

    _dio.options.baseUrl = 'https://$_storeUrl/admin/api/$_apiVersion';
    print('🌐 Admin API URL: ${_dio.options.baseUrl}');

    _dio.options.headers = {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': _adminToken,
    };
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(seconds: 30);
  }

  /// Creates and completes a COD order using Shopify Admin API
  Future<Map<String, dynamic>> createAndCompleteCODOrder({
    required List<CartLineInput> lineItems,
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
    required String address1,
    String city = 'Kuwait City',
    String province = 'Al Asimah',
    String zip = '00000',
    String countryCode = 'KW',
  }) async {
    try {
      // Step 1: Create draft order
      final draftOrderId = await _createDraftOrder(
        lineItems: lineItems,
        email: email,
        phone: phone,
        firstName: firstName,
        lastName: lastName,
        address1: address1,
        city: city,
        province: province,
        zip: zip,
        countryCode: countryCode,
      );

      print('✅ Draft order created: $draftOrderId');

      // Step 2: Complete the draft order (COD - payment pending)
      final orderDetails = await _completeDraftOrder(draftOrderId);

      print('✅ Order completed: ${orderDetails['orderNumber']}');

      return orderDetails;
    } catch (e) {
      print('❌ Error creating COD order: $e');
      rethrow;
    }
  }

  /// Step 1: Create a draft order
  Future<String> _createDraftOrder({
    required List<CartLineInput> lineItems,
    required String email,
    required String phone,
    required String firstName,
    required String lastName,
    required String address1,
    required String city,
    required String province,
    required String zip,
    required String countryCode,
  }) async {
    const mutation = r'''
      mutation draftOrderCreate($input: DraftOrderInput!) {
        draftOrderCreate(input: $input) {
          draftOrder {
            id
            name
            totalPriceSet {
              shopMoney {
                amount
                currencyCode
              }
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    ''';

    // Debug line items
    print('📦 Processing ${lineItems.length} line items:');
    for (int i = 0; i < lineItems.length; i++) {
      final item = lineItems[i];
      print(
        '  Item $i: merchandiseId=${item.merchandiseId}, quantity=${item.quantity}',
      );
    }

    final variables = {
      'input': {
        'email': email,
        'lineItems': lineItems.map((item) {
          // Extract variant ID from merchandise ID (remove gid prefix if present)
          final variantId = item.merchandiseId.contains('ProductVariant')
              ? item.merchandiseId
              : 'gid://shopify/ProductVariant/${item.merchandiseId}';

          print('  Mapped variantId: $variantId');
          return {'variantId': variantId, 'quantity': item.quantity};
        }).toList(),
        'shippingAddress': {
          'firstName': firstName,
          'lastName': lastName,
          'address1': address1,
          'city': city,
          'province': province,
          'zip': zip,
          'country': countryCode,
          'phone': phone,
        },
        'billingAddress': {
          'firstName': firstName,
          'lastName': lastName,
          'address1': address1,
          'city': city,
          'province': province,
          'zip': zip,
          'country': countryCode,
          'phone': phone,
        },
        'tags': ['COD', 'Mobile App', 'Flutter'],
        'note': 'COD Order - Payment pending on delivery',
      },
    };

    try {
      final response = await _dio.post(
        '/graphql.json',
        data: {'query': mutation, 'variables': variables},
      );

      print('📦 Draft order creation response: ${response.data}');
      print('📦 Response status: ${response.statusCode}');
      print('📦 Response headers: ${response.headers}');

      final data = response.data as Map<String, dynamic>;

      // Check for GraphQL errors first
      if (data.containsKey('errors')) {
        final errors = data['errors'] as List;
        print('❌ GraphQL errors: $errors');
        throw Exception(
          'GraphQL errors: ${errors.map((e) => e['message']).join(', ')}',
        );
      }

      final draftOrderCreate = data['data']?['draftOrderCreate'];

      if (draftOrderCreate == null) {
        print('❌ No draftOrderCreate in response data: $data');
        throw Exception(
          'Invalid response from Shopify Admin API - no draftOrderCreate',
        );
      }

      final userErrors = draftOrderCreate['userErrors'] as List?;
      if (userErrors != null && userErrors.isNotEmpty) {
        final errorMessage = userErrors.first['message'] as String;
        print('❌ User errors: $userErrors');
        throw Exception('فشل في إنشاء الطلب: $errorMessage');
      }

      final draftOrder = draftOrderCreate['draftOrder'];
      if (draftOrder == null) {
        print('❌ No draftOrder in response: $draftOrderCreate');
        throw Exception('فشل في إنشاء الطلب - no draft order');
      }

      print('✅ Draft order created successfully: ${draftOrder['id']}');
      return draftOrder['id'] as String;
    } on DioException catch (e) {
      print('❌ Dio error: ${e.response?.data}');
      print('❌ Dio error status: ${e.response?.statusCode}');
      print('❌ Dio error message: ${e.message}');
      throw Exception('فشل في الاتصال بالخادم: ${e.message}');
    }
  }

  /// Step 2: Complete the draft order
  Future<Map<String, dynamic>> _completeDraftOrder(String draftOrderId) async {
    const mutation = r'''
       mutation draftOrderComplete($id: ID!, $paymentPending: Boolean!) {
         draftOrderComplete(id: $id, paymentPending: $paymentPending) {
           draftOrder {
             id
             name
             totalPriceSet {
               shopMoney {
                 amount
                 currencyCode
               }
             }
           }
           userErrors {
             field
             message
           }
         }
       }
     ''';

    final variables = {
      'id': draftOrderId,
      'paymentPending': true, // COD = payment pending
    };

    try {
      final response = await _dio.post(
        '/graphql.json',
        data: {'query': mutation, 'variables': variables},
      );

      print('✅ Draft order completion response: ${response.data}');
      print('✅ Response status: ${response.statusCode}');

      final data = response.data as Map<String, dynamic>;

      // Check for GraphQL errors first
      if (data.containsKey('errors')) {
        final errors = data['errors'] as List;
        print('❌ GraphQL errors: $errors');
        throw Exception(
          'GraphQL errors: ${errors.map((e) => e['message']).join(', ')}',
        );
      }

      final draftOrderComplete = data['data']?['draftOrderComplete'];

      if (draftOrderComplete == null) {
        print('❌ No draftOrderComplete in response data: $data');
        throw Exception(
          'Invalid response from Shopify Admin API - no draftOrderComplete',
        );
      }

      final userErrors = draftOrderComplete['userErrors'] as List?;
      if (userErrors != null && userErrors.isNotEmpty) {
        final errorMessage = userErrors.first['message'] as String;
        print('❌ User errors: $userErrors');
        throw Exception('فشل في إتمام الطلب: $errorMessage');
      }

      final draftOrder = draftOrderComplete['draftOrder'];
      if (draftOrder == null) {
        print('❌ No draftOrder in response: $draftOrderComplete');
        throw Exception('فشل في إتمام الطلب - no draft order');
      }

      final totalPrice = draftOrder['totalPriceSet']['shopMoney'];

      print('✅ Order completed successfully: ${draftOrder['name']}');
      return {
        'orderId': draftOrder['id'] as String,
        'orderName': draftOrder['name'] as String,
        'orderNumber':
            draftOrder['name'], // Use draft order name as order number
        'totalPrice': '${totalPrice['amount']} ${totalPrice['currencyCode']}',
        'financialStatus': 'Pending', // COD orders are always pending payment
        'fulfillmentStatus': 'Unfulfilled', // New orders start as unfulfilled
      };
    } on DioException catch (e) {
      print('❌ Dio error: ${e.response?.data}');
      print('❌ Dio error status: ${e.response?.statusCode}');
      print('❌ Dio error message: ${e.message}');
      throw Exception('فشل في الاتصال بالخادم: ${e.message}');
    }
  }
}
