class CartItem {
  final String id;
  final String variantId;
  final String title;
  final int quantity;
  final double price;

  CartItem({
    required this.id,
    required this.variantId,
    required this.title,
    required this.quantity,
    required this.price,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      id: json['id'] ?? '',
      variantId: json['variantId'] ?? '',
      title: json['title'] ?? 'Product',
      quantity: json['quantity'] ?? 0,
      price: json['price'] ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'variantId': variantId,
      'title': title,
      'quantity': quantity,
      'price': price,
    };
  }
}
