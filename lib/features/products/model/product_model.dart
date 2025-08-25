class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final List<String> images;
  final String variantId;

  Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.images,
    required this.variantId,
  });

  /// Get the first image URL or empty string if no images
  String get imageUrl => images.isNotEmpty ? images.first : '';

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
      images: List<String>.from(json['images'] ?? []),
      variantId: json['variantId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'images': images,
      'variantId': variantId,
    };
  }
}
