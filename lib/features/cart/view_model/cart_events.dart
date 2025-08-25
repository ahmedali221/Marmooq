abstract class CartEvent {}

class CreateCart extends CartEvent {}

class AddItemToCart extends CartEvent {
  final String variantId;
  final String title;
  final double price;
  final int quantity;

  AddItemToCart({
    required this.variantId,
    required this.title,
    required this.price,
    required this.quantity,
  });
}

class UpdateItemQuantity extends CartEvent {
  final String lineId;
  final String variantId;
  final String title;
  final double price;
  final int newQuantity;

  UpdateItemQuantity({
    required this.lineId,
    required this.variantId,
    required this.title,
    required this.price,
    required this.newQuantity,
  });
}

class RemoveItemFromCart extends CartEvent {
  final String lineId;

  RemoveItemFromCart({required this.lineId});
}

class ApplyDiscountCode extends CartEvent {
  final String discountCode;

  ApplyDiscountCode({required this.discountCode});
}

class UpdateCartNote extends CartEvent {
  final String note;

  UpdateCartNote({required this.note});
}

class ValidateCartForCheckout extends CartEvent {}
