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

  /// Convert to Shopify's CartBuyerIdentityInput format
  Map<String, dynamic> toShopifyAddress() {
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