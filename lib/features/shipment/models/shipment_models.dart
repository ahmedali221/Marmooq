import 'package:equatable/equatable.dart';

/// Model class representing a shipping address
class AddressModel extends Equatable {
  final String? firstName;
  final String? lastName;
  final String? address1;
  final String? address2;
  final String? city;
  final String? province;
  final String? country;
  final String? zip;
  final String? phone;
  final String? company;

  const AddressModel({
    this.firstName,
    this.lastName,
    this.address1,
    this.address2,
    this.city,
    this.province,
    this.country,
    this.zip,
    this.phone,
    this.company,
  });

  /// Creates a copy of this AddressModel with the given fields replaced with new values
  AddressModel copyWith({
    String? firstName,
    String? lastName,
    String? address1,
    String? address2,
    String? city,
    String? province,
    String? country,
    String? zip,
    String? phone,
    String? company,
  }) {
    return AddressModel(
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      province: province ?? this.province,
      country: country ?? this.country,
      zip: zip ?? this.zip,
      phone: phone ?? this.phone,
      company: company ?? this.company,
    );
  }

  /// Create from map (for persistence)
  factory AddressModel.fromMap(Map<String, dynamic> map) {
    return AddressModel(
      firstName: map['firstName'],
      lastName: map['lastName'],
      address1: map['address1'],
      address2: map['address2'],
      city: map['city'],
      province: map['province'],
      country: map['country'],
      zip: map['zip'],
      phone: map['phone'],
      company: map['company'],
    );
  }

  /// Convert to map (for persistence)
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'address1': address1,
      'address2': address2,
      'city': city,
      'province': province,
      'country': country,
      'zip': zip,
      'phone': phone,
      'company': company,
    };
  }

  /// Check if address is complete with required fields
  bool get isComplete {
    return firstName != null &&
        lastName != null &&
        address1 != null &&
        city != null &&
        province != null &&
        country != null &&
        zip != null &&
        phone != null;
  }

  @override
  List<Object?> get props => [
    firstName,
    lastName,
    address1,
    address2,
    city,
    province,
    country,
    zip,
    phone,
    company,
  ];
}

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
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      isAvailable: isAvailable ?? this.isAvailable,
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

/// Model class representing a complete shipment with address and selected shipping method
class ShipmentModel extends Equatable {
  final String? id;
  final AddressModel? shippingAddress;
  final AddressModel? billingAddress;
  final ShippingMethodModel? selectedShippingMethod;
  final bool useSameAddressForBilling;
  final String? specialInstructions;
  final bool isComplete;

  const ShipmentModel({
    this.id,
    this.shippingAddress,
    this.billingAddress,
    this.selectedShippingMethod,
    this.useSameAddressForBilling = true,
    this.specialInstructions,
    this.isComplete = false,
  });

  /// Creates a copy of this ShipmentModel with the given fields replaced with new values
  ShipmentModel copyWith({
    String? id,
    AddressModel? shippingAddress,
    AddressModel? billingAddress,
    ShippingMethodModel? selectedShippingMethod,
    bool? useSameAddressForBilling,
    String? specialInstructions,
    bool? isComplete,
  }) {
    return ShipmentModel(
      id: id ?? this.id,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      billingAddress: billingAddress ?? this.billingAddress,
      selectedShippingMethod:
          selectedShippingMethod ?? this.selectedShippingMethod,
      useSameAddressForBilling:
          useSameAddressForBilling ?? this.useSameAddressForBilling,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  /// Create from map (for persistence)
  factory ShipmentModel.fromMap(Map<String, dynamic> map) {
    return ShipmentModel(
      id: map['id'],
      shippingAddress: map['shippingAddress'] != null
          ? AddressModel.fromMap(map['shippingAddress'])
          : null,
      billingAddress: map['billingAddress'] != null
          ? AddressModel.fromMap(map['billingAddress'])
          : null,
      selectedShippingMethod: map['selectedShippingMethod'] != null
          ? ShippingMethodModel.fromMap(map['selectedShippingMethod'])
          : null,
      useSameAddressForBilling: map['useSameAddressForBilling'] ?? true,
      specialInstructions: map['specialInstructions'],
      isComplete: map['isComplete'] ?? false,
    );
  }

  /// Convert to map (for persistence)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shippingAddress': shippingAddress?.toMap(),
      'billingAddress': billingAddress?.toMap(),
      'selectedShippingMethod': selectedShippingMethod?.toMap(),
      'useSameAddressForBilling': useSameAddressForBilling,
      'specialInstructions': specialInstructions,
      'isComplete': isComplete,
    };
  }

  /// Check if shipment is ready for checkout
  bool get isReadyForCheckout {
    final hasValidShippingAddress = shippingAddress?.isComplete ?? false;
    final hasValidBillingAddress = useSameAddressForBilling
        ? true
        : billingAddress?.isComplete ?? false;
    final hasShippingMethod = selectedShippingMethod != null;

    return hasValidShippingAddress &&
        hasValidBillingAddress &&
        hasShippingMethod;
  }

  /// Get effective billing address (either dedicated billing address or shipping address if same)
  AddressModel? get effectiveBillingAddress {
    return useSameAddressForBilling ? shippingAddress : billingAddress;
  }

  @override
  List<Object?> get props => [
    id,
    shippingAddress,
    billingAddress,
    selectedShippingMethod,
    useSameAddressForBilling,
    specialInstructions,
    isComplete,
  ];
}
