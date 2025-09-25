import 'package:equatable/equatable.dart';

/// Model class representing a shipping method option
class ShippingMethodModel extends Equatable {
  final String id;
  final String title;
  final String description;
  final double price;
  final String? estimatedDeliveryTime;
  final bool isAvailable;

  const ShippingMethodModel({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.estimatedDeliveryTime,
    this.isAvailable = true,
  });

  /// Creates a copy of this ShippingMethodModel with the given fields replaced with new values
  ShippingMethodModel copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? estimatedDeliveryTime,
    bool? isAvailable,
  }) {
    return ShippingMethodModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      estimatedDeliveryTime: estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }

  /// Create from Shopify's shipping rate format
  factory ShippingMethodModel.fromShopifyShippingRate(Map<String, dynamic> rate) {
    return ShippingMethodModel(
      id: rate['handle'] ?? '',
      title: rate['title'] ?? '',
      description: rate['title'] ?? '', // Shopify often doesn't provide separate description
      price: double.tryParse(rate['price']?.toString() ?? '0') ?? 0.0,
      estimatedDeliveryTime: rate['estimatedDeliveryTime'],
      isAvailable: true,
    );
  }

  /// Create from map (for persistence)
  factory ShippingMethodModel.fromMap(Map<String, dynamic> map) {
    return ShippingMethodModel(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      price: map['price']?.toDouble() ?? 0.0,
      estimatedDeliveryTime: map['estimatedDeliveryTime'],
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  /// Convert to map (for persistence)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'estimatedDeliveryTime': estimatedDeliveryTime,
      'isAvailable': isAvailable,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        price,
        estimatedDeliveryTime,
        isAvailable,
      ];
}
