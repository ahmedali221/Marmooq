import 'package:equatable/equatable.dart';
import 'package:shopify_flutter/models/src/cart/cart.dart';

abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {
  const CartInitial();
}

class CartLoading extends CartState {
  const CartLoading();
}

class CartSuccess extends CartState {
  final Cart cart;

  const CartSuccess(this.cart);

  @override
  List<Object?> get props => [cart];
}

class CartFailure extends CartState {
  final String error;

  const CartFailure(this.error);

  @override
  List<Object?> get props => [error];
}

class CartInitialized extends CartState {
  final Cart cart;
  final bool isNewCart;

  const CartInitialized(this.cart, {this.isNewCart = false});

  @override
  List<Object?> get props => [cart, isNewCart];
}
