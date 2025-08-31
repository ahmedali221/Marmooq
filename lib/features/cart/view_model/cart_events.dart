import 'package:equatable/equatable.dart';
import 'package:shopify_flutter/models/src/cart/inputs/attribute_input/attribute_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class CreateCartEvent extends CartEvent {
  final String? note;
  final List<String>? discountCodes;
  final List<AttributeInput>? attributes;

  const CreateCartEvent({this.note, this.discountCodes, this.attributes});

  @override
  List<Object?> get props => [note, discountCodes, attributes];

  @override
  String toString() =>
      'CreateCartEvent(note: $note, discountCodes: $discountCodes, attributes: $attributes)';
}

class LoadCartEvent extends CartEvent {
  const LoadCartEvent();

  @override
  String toString() => 'LoadCartEvent()';
}

class GetCartByIdEvent extends CartEvent {
  final String cartId;

  const GetCartByIdEvent(this.cartId);

  @override
  List<Object?> get props => [cartId];

  @override
  String toString() => 'GetCartByIdEvent(cartId: $cartId)';
}

class AddItemsToCartEvent extends CartEvent {
  final String cartId;
  final List<CartLineUpdateInput> cartLineInputs;
  final bool reverse;

  const AddItemsToCartEvent({
    required this.cartId,
    required this.cartLineInputs,
    this.reverse = false,
  });

  @override
  List<Object?> get props => [cartId, cartLineInputs, reverse];

  @override
  String toString() =>
      'AddItemsToCartEvent(cartId: $cartId, items: ${cartLineInputs.length}, reverse: $reverse)';
}

class RefreshCartEvent extends CartEvent {
  const RefreshCartEvent();

  @override
  String toString() => 'RefreshCartEvent()';
}

class CartClearedEvent extends CartEvent {
  const CartClearedEvent();

  @override
  String toString() => 'CartClearedEvent()';
}
