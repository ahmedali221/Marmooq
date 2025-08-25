import 'package:bloc/bloc.dart';
import 'package:shopify_flutter/models/src/cart/cart.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_input/cart_line_input.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';
import '../repository/cart_repository.dart';
import '../model/cart_Item.dart';
import 'cart_events.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartRepository _cartRepository;

  CartBloc({CartRepository? cartRepository})
    : _cartRepository = cartRepository ?? CartRepository(),
      super(CartInitial()) {
    on<CreateCart>(_onCreateCart);
    on<AddItemToCart>(_onAddItemToCart);
    on<UpdateItemQuantity>(_onUpdateItemQuantity);
    on<RemoveItemFromCart>(_onRemoveItemFromCart);
    on<ApplyDiscountCode>(_onApplyDiscountCode);
    on<UpdateCartNote>(_onUpdateCartNote);
    on<ValidateCartForCheckout>(_onValidateCartForCheckout);
  }

  Future<void> _onCreateCart(CreateCart event, Emitter<CartState> emit) async {
    emit(CartLoading());
    try {
      final cart = await _cartRepository.createCart();
      final cartItems = _cartRepository.mapToCartItems(cart);
      final totals = _cartRepository.calculateCartTotals(cart);
      emit(CartLoaded(cart: cart, cartItems: cartItems, totals: totals));
    } catch (e) {
      emit(CartError(message: e.toString()));
    }
  }

  Future<void> _onAddItemToCart(
    AddItemToCart event,
    Emitter<CartState> emit,
  ) async {
    emit(CartLoading());
    try {
      Cart cart;
      if (state is CartLoaded) {
        cart = (state as CartLoaded).cart;
      } else {
        cart = await _cartRepository.createCart();
      }

      final cartLineInput = CartLineInput(
        merchandiseId: event.variantId,
        quantity: event.quantity,
      );

      final updatedCart = await _cartRepository.addItemsToCart(
        cartId: cart.id,
        cartLineInputs: [cartLineInput],
      );

      final cartItems = _cartRepository.mapToCartItems(updatedCart);
      final totals = _cartRepository.calculateCartTotals(updatedCart);
      emit(CartLoaded(cart: updatedCart, cartItems: cartItems, totals: totals));
    } catch (e) {
      emit(CartError(message: e.toString()));
    }
  }

  Future<void> _onUpdateItemQuantity(
    UpdateItemQuantity event,
    Emitter<CartState> emit,
  ) async {
    if (state is! CartLoaded) return;
    emit(CartLoading());
    try {
      final cart = (state as CartLoaded).cart;

      if (event.newQuantity <= 0) {
        // Remove item if quantity is 0 or less
        add(RemoveItemFromCart(lineId: event.lineId));
        return;
      }

      final cartLineUpdateInput = CartLineUpdateInput(
        id: event.lineId,
        merchandiseId: event.variantId,
        quantity: event.newQuantity,
      );

      final updatedCart = await _cartRepository.updateItemsInCart(
        cartId: cart.id,
        cartLineInputs: [cartLineUpdateInput],
      );

      final cartItems = _cartRepository.mapToCartItems(updatedCart);
      final totals = _cartRepository.calculateCartTotals(updatedCart);
      emit(CartLoaded(cart: updatedCart, cartItems: cartItems, totals: totals));
    } catch (e) {
      emit(CartError(message: e.toString()));
    }
  }

  Future<void> _onRemoveItemFromCart(
    RemoveItemFromCart event,
    Emitter<CartState> emit,
  ) async {
    if (state is! CartLoaded) return;
    emit(CartLoading());
    try {
      final cart = (state as CartLoaded).cart;
      final updatedCart = await _cartRepository.removeItemsFromCart(
        cartId: cart.id,
        lineIds: [event.lineId],
      );

      final cartItems = _cartRepository.mapToCartItems(updatedCart);
      final totals = _cartRepository.calculateCartTotals(updatedCart);
      emit(CartLoaded(cart: updatedCart, cartItems: cartItems, totals: totals));
    } catch (e) {
      emit(CartError(message: e.toString()));
    }
  }

  Future<void> _onApplyDiscountCode(
    ApplyDiscountCode event,
    Emitter<CartState> emit,
  ) async {
    if (state is! CartLoaded) return;
    emit(CartLoading());
    try {
      final cart = (state as CartLoaded).cart;
      final currentDiscounts =
          cart.discountCodes?.map((d) => d!.code).toList() ?? [];
      final updatedDiscounts = [...currentDiscounts, event.discountCode];

      final updatedCart = await _cartRepository.updateDiscountCodes(
        cartId: cart.id,
        discountCodes: updatedDiscounts.whereType<String>().toList(),
      );

      final cartItems = _cartRepository.mapToCartItems(updatedCart);
      final totals = _cartRepository.calculateCartTotals(updatedCart);
      emit(CartLoaded(cart: updatedCart, cartItems: cartItems, totals: totals));
    } catch (e) {
      emit(CartError(message: e.toString()));
    }
  }

  Future<void> _onUpdateCartNote(
    UpdateCartNote event,
    Emitter<CartState> emit,
  ) async {
    if (state is! CartLoaded) return;
    try {
      final cart = (state as CartLoaded).cart;
      final updatedCart = await _cartRepository.updateCartNote(
        cartId: cart.id,
        note: event.note,
      );

      final cartItems = _cartRepository.mapToCartItems(updatedCart);
      final totals = _cartRepository.calculateCartTotals(updatedCart);
      emit(CartLoaded(cart: updatedCart, cartItems: cartItems, totals: totals));
    } catch (e) {
      emit(CartError(message: e.toString()));
    }
  }

  Future<void> _onValidateCartForCheckout(
    ValidateCartForCheckout event,
    Emitter<CartState> emit,
  ) async {
    if (state is! CartLoaded) return;
    try {
      final cart = (state as CartLoaded).cart;
      final isValid = await _cartRepository.validateCartForCheckout(cart.id);

      if (isValid) {
        emit(
          CartReadyForCheckout(
            cart: cart,
            cartItems: (state as CartLoaded).cartItems,
            totals: (state as CartLoaded).totals,
          ),
        );
      }
    } catch (e) {
      emit(CartError(message: e.toString()));
    }
  }
}
