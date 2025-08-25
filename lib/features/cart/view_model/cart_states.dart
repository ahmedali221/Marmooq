import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/features/cart/model/cart_Item.dart';
import '../repository/cart_repository.dart';

abstract class CartState {}

class CartInitial extends CartState {}

class CartLoading extends CartState {}

class CartLoaded extends CartState {
  final Cart cart;
  final List<CartItem> cartItems;
  final CartTotals totals;

  CartLoaded({
    required this.cart,
    required this.cartItems,
    required this.totals,
  });
}

class CartReadyForCheckout extends CartLoaded {
  CartReadyForCheckout({
    required Cart cart,
    required List<CartItem> cartItems,
    required CartTotals totals,
  }) : super(cart: cart, cartItems: cartItems, totals: totals);
}

class CartError extends CartState {
  final String message;

  CartError({required this.message});
}
