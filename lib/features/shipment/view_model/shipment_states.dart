import 'package:equatable/equatable.dart';

abstract class ShippingState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ShippingInitial extends ShippingState {}

class ShippingLoading extends ShippingState {}

class ShippingSuccess extends ShippingState {
  final String message;

  ShippingSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class ShippingError extends ShippingState {
  final String error;

  ShippingError(this.error);

  @override
  List<Object?> get props => [error];
}

class CheckoutCreated extends ShippingState {
  final String checkoutId;
  final String webUrl;
  final List<Map<String, dynamic>> availableShippingRates;

  CheckoutCreated({
    required this.checkoutId,
    required this.webUrl,
    required this.availableShippingRates,
  });

  @override
  List<Object?> get props => [checkoutId, webUrl, availableShippingRates];
}
