import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:traincode/core/network/dio_client.dart';
import 'package:traincode/features/products/model/product_failure.dart';
import 'package:traincode/features/products/model/product_model.dart';

class ProductsRepository {
  // USD to KWD conversion rate (approximate)
  static const double _usdToKwdRate = 0.31;

  Future<Either<ProductFailure, List<Product>>> getProducts() async {
    try {
      const String query = '''
        query {
          products(first: 10) {
            nodes {
              id
              title
              description
              variants(first:1) {
                nodes {
                  price {
                    amount
                    currencyCode
                  }
                }
              }
              images(first: 10) {
                nodes {
                  url
                }
              }
            }
          }
        }
      ''';
      final response = await DioClient.instance.storefrontGraphQL(query);
      if (response.statusCode == 200) {
        final data =
            response.data['data']['products']['nodes'] as List<dynamic>;
        if (data.isEmpty) {
          return left(NoProductsFailure());
        }
        final products = data.map((json) {
          final gid = json['id'] as String;
          final id =
              int.tryParse(gid.split('/').last) ??
              0; // Extract numeric ID from GID
          final priceStr =
              json['variants']['nodes'][0]['price']['amount'] as String;
          final usdPrice = double.tryParse(priceStr) ?? 0.0;
          // Convert USD to KWD
          final kwdPrice = usdPrice * _usdToKwdRate;
          final imageNodes = json['images']['nodes'] as List<dynamic>;
          final images = imageNodes
              .map((node) => node['url'] as String)
              .toList();
          return Product(
            id: id,
            name: json['title'] as String,
            description: json['description'] as String,
            price: kwdPrice,
            images: images,
          );
        }).toList();
        return right(products);
      } else {
        return left(
          ServerFailure('Failed to fetch products: ${response.statusCode}'),
        );
      }
    } on DioException catch (e) {
      return left(ServerFailure(e.message ?? 'Unknown error'));
    } catch (e) {
      return left(ServerFailure(e.toString()));
    }
  }
}
