import 'package:flutter/material.dart';
import 'package:traincode/features/products/model/product_model.dart';
import 'package:traincode/features/products/view/product_details_view.dart';

class CollectionDetailsView extends StatelessWidget {
  final String collectionName;
  final List<Product> products;

  const CollectionDetailsView({
    super.key,
    required this.collectionName,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(collectionName),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
        ),
        body: products.isEmpty
            ? Center(child: Text('لا توجد منتجات في هذه المجموعة'))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  final product = products[index];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsView(product: product),
                      ),
                    ),
                    child: Card(
                      elevation: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Image.network(
                              product.images.isNotEmpty ? product.images.first : 'https://via.placeholder.com/150',
                              fit: BoxFit.cover,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('${product.price.toStringAsFixed(2)} د.ك'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}