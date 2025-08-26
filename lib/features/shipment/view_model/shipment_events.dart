import 'package:equatable/equatable.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

abstract class ShippingEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SubmitShippingAddress extends ShippingEvent {
  final String customerAccessToken;
  final String cartId;
  final String email;
  final String address1;
  final String? address2;
  final String city;
  final String country;
  final String province;
  final String zip;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? company;
  final List<CartLineInput> lineItems;

  SubmitShippingAddress({
    required this.customerAccessToken,
    required this.cartId,
    required this.email,
    required this.address1,
    this.address2,
    required this.city,
    required this.country,
    required this.province,
    required this.zip,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.company,
    required this.lineItems,
  });

  @override
  List<Object?> get props => [
    customerAccessToken,
    cartId,
    email,
    address1,
    address2,
    city,
    country,
    province,
    zip,
    firstName,
    lastName,
    phone,
    company,
    lineItems,
  ];
}
