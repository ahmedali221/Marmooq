import 'package:bloc/bloc.dart';
import 'package:traincode/core/services/security_service.dart';
import 'package:traincode/features/cart/repository/cart_repository.dart';
import 'package:traincode/features/cart/view_model/cart_events.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartRepository cartRepository;

  CartBloc({required this.cartRepository}) : super(const CartInitial()) {
    on<CreateCartEvent>(_onCreateCart);
    on<LoadCartEvent>(_onLoadCart);
    on<GetCartByIdEvent>(_onGetCartById);
    on<AddItemsToCartEvent>(_onAddItemsToCart);
    on<RefreshCartEvent>(_onRefreshCart);
    on<CartClearedEvent>(_onCartCleared);
    on<UpdateCartLineItemsEvent>(_onUpdateCartLineItems);
  }

  Future<void> _onCreateCart(
    CreateCartEvent event,
    Emitter<CartState> emit,
  ) async {
    // Log event for debugging
    print('DEBUG: Received event: $event');
    emit(const CartLoading());
    print('DEBUG: Emitted CartLoading state');

    try {
      // Call repository to create cart
      print('DEBUG: Calling CartRepository.createCart...');
      final cart = await cartRepository.createCart(
        note: event.note,
        discountCodes: event.discountCodes,
        attributes: event.attributes,
      );

      // Log success and emit state
      print('DEBUG: Cart created successfully with ID: ${cart.id}');
      emit(CartInitialized(cart, isNewCart: true));
      print('DEBUG: Emitted CartInitialized state with isNewCart=true');
    } catch (e) {
      // Log error and emit failure state
      print('DEBUG: Error in CartBloc: $e');
      emit(CartFailure(e.toString()));
      print('DEBUG: Emitted CartFailure state with error: $e');
    }
  }

  Future<void> _onLoadCart(LoadCartEvent event, Emitter<CartState> emit) async {
    print('DEBUG: Received event: $event');
    emit(const CartLoading());
    print('DEBUG: Emitted CartLoading state');

    try {
      // Get stored cart ID
      final cartId = await SecurityService.getCartId();
      print('DEBUG: Retrieved stored cart ID: $cartId');

      if (cartId == null) {
        // No stored cart ID, create a new cart
        print('DEBUG: No stored cart ID found, creating a new cart');
        final cart = await cartRepository.createCart();
        emit(CartInitialized(cart, isNewCart: true));
        print('DEBUG: Emitted CartInitialized state with isNewCart=true');
      } else {
        // Try to get the cart by ID
        try {
          print('DEBUG: Retrieving cart with ID: $cartId');
          final cart = await cartRepository.getCartById(cartId);
          emit(CartInitialized(cart, isNewCart: false));
          print('DEBUG: Emitted CartInitialized state with isNewCart=false');
        } catch (e) {
          // If cart retrieval fails, create a new cart
          print('DEBUG: Failed to retrieve cart, creating a new one: $e');
          final cart = await cartRepository.createCart();
          emit(CartInitialized(cart, isNewCart: true));
          print('DEBUG: Emitted CartInitialized state with isNewCart=true');
        }
      }
    } catch (e) {
      print('DEBUG: Error in _onLoadCart: $e');
      emit(CartFailure(e.toString()));
      print('DEBUG: Emitted CartFailure state with error: $e');
    }
  }

  Future<void> _onGetCartById(
    GetCartByIdEvent event,
    Emitter<CartState> emit,
  ) async {
    print('DEBUG: Received event: $event');
    emit(const CartLoading());
    print('DEBUG: Emitted CartLoading state');

    try {
      print('DEBUG: Retrieving cart with ID: ${event.cartId}');
      final cart = await cartRepository.getCartById(event.cartId);
      emit(CartSuccess(cart));
      print('DEBUG: Emitted CartSuccess state');
    } catch (e) {
      print('DEBUG: Error in _onGetCartById: $e');
      emit(CartFailure(e.toString()));
      print('DEBUG: Emitted CartFailure state with error: $e');
    }
  }

  Future<void> _onAddItemsToCart(
    AddItemsToCartEvent event,
    Emitter<CartState> emit,
  ) async {
    print('DEBUG: Received event: $event');
    emit(const CartLoading());
    print('DEBUG: Emitted CartLoading state');

    try {
      print('DEBUG: Adding items to cart with ID: ${event.cartId}');
      final cart = await cartRepository.addItemsToCart(
        cartId: event.cartId,
        cartLineInputs: event.cartLineInputs,
        reverse: event.reverse,
      );
      emit(CartSuccess(cart));
      print('DEBUG: Emitted CartSuccess state');
    } catch (e) {
      print('DEBUG: Error in _onAddItemsToCart: $e');
      emit(CartFailure(e.toString()));
      print('DEBUG: Emitted CartFailure state with error: $e');
    }
  }

  Future<void> _onRefreshCart(
    RefreshCartEvent event,
    Emitter<CartState> emit,
  ) async {
    print('DEBUG: Received event: $event');
    emit(const CartLoading());
    print('DEBUG: Emitted CartLoading state');

    try {
      // Get stored cart ID
      final cartId = await SecurityService.getCartId();
      print('DEBUG: Refreshing cart, stored cart ID: $cartId');

      if (cartId == null) {
        // No stored cart ID, create a new cart
        print('DEBUG: No stored cart ID found, creating a new cart');
        final cart = await cartRepository.createCart();
        emit(CartInitialized(cart, isNewCart: true));
        print('DEBUG: Emitted CartInitialized state with isNewCart=true');
      } else {
        // Try to get the cart by ID
        try {
          print('DEBUG: Retrieving cart with ID: $cartId');
          final cart = await cartRepository.getCartById(cartId);
          emit(CartInitialized(cart, isNewCart: false));
          print('DEBUG: Emitted CartInitialized state with isNewCart=false');
        } catch (e) {
          // If cart retrieval fails, create a new cart
          print('DEBUG: Failed to retrieve cart, creating a new one: $e');
          final cart = await cartRepository.createCart();
          emit(CartInitialized(cart, isNewCart: true));
          print('DEBUG: Emitted CartInitialized state with isNewCart=true');
        }
      }
    } catch (e) {
      print('DEBUG: Error in _onRefreshCart: $e');
      emit(CartFailure(e.toString()));
      print('DEBUG: Emitted CartFailure state with error: $e');
    }
  }

  Future<void> _onCartCleared(
    CartClearedEvent event,
    Emitter<CartState> emit,
  ) async {
    print('DEBUG: Received event: $event');
    emit(const CartLoading());
    print('DEBUG: Emitted CartLoading state');

    try {
      // Create a new empty cart
      print('DEBUG: Creating new empty cart after clearing');
      final cart = await cartRepository.createCart();
      emit(CartInitialized(cart, isNewCart: true));
      print(
        'DEBUG: Emitted CartInitialized state with isNewCart=true for cleared cart',
      );
    } catch (e) {
      print('DEBUG: Error in _onCartCleared: $e');
      emit(CartFailure(e.toString()));
      print('DEBUG: Emitted CartFailure state with error: $e');
    }
  }

  Future<void> _onUpdateCartLineItems(
    UpdateCartLineItemsEvent event,
    Emitter<CartState> emit,
  ) async {
    print('DEBUG: Received event: $event');
    emit(const CartLoading());
    print('DEBUG: Emitted CartLoading state');

    try {
      print('DEBUG: Updating line items in cart with ID: ${event.cartId}');
      final cart = await cartRepository.updateLineItemsInCart(
        cartId: event.cartId,
        cartLineInputs: event.cartLineInputs,
        reverse: event.reverse,
      );
      emit(CartSuccess(cart));
      print('DEBUG: Emitted CartSuccess state after updating line items');
    } catch (e) {
      print('DEBUG: Error in _onUpdateCartLineItems: $e');
      emit(CartFailure(e.toString()));
      print('DEBUG: Emitted CartFailure state with error: $e');
    }
  }
}
