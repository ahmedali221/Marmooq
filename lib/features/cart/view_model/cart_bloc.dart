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
    emit(const CartLoading());

    try {
      // Call repository to create cart
      final cart = await cartRepository.createCart(
        note: event.note,
        discountCodes: event.discountCodes,
        attributes: event.attributes,
      );

      // Emit success state
      emit(CartInitialized(cart, isNewCart: true));
    } catch (e) {
      // Emit failure state
      emit(CartFailure(e.toString()));
    }
  }

  Future<void> _onLoadCart(LoadCartEvent event, Emitter<CartState> emit) async {
    emit(const CartLoading());

    try {
      // Get stored cart ID
      final cartId = await SecurityService.getCartId();

      if (cartId == null) {
        // No stored cart ID, create a new cart
        final cart = await cartRepository.createCart();
        emit(CartInitialized(cart, isNewCart: true));
      } else {
        // Try to get the cart by ID
        try {
          final cart = await cartRepository.getCartById(cartId);
          emit(CartInitialized(cart, isNewCart: false));
        } catch (e) {
          // If cart retrieval fails, create a new cart
          final cart = await cartRepository.createCart();
          emit(CartInitialized(cart, isNewCart: true));
        }
      }
    } catch (e) {
      emit(CartFailure(e.toString()));
    }
  }

  Future<void> _onGetCartById(
    GetCartByIdEvent event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());

    try {
      final cart = await cartRepository.getCartById(event.cartId);
      emit(CartSuccess(cart));
    } catch (e) {
      emit(CartFailure(e.toString()));
    }
  }

  Future<void> _onAddItemsToCart(
    AddItemsToCartEvent event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());

    try {
      final cart = await cartRepository.addItemsToCart(
        cartId: event.cartId,
        cartLineInputs: event.cartLineInputs,
        reverse: event.reverse,
      );
      emit(CartSuccess(cart));
    } catch (e) {
      emit(CartFailure(e.toString()));
    }
  }

  Future<void> _onRefreshCart(
    RefreshCartEvent event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());

    try {
      // Get stored cart ID
      final cartId = await SecurityService.getCartId();

      if (cartId == null) {
        // No stored cart ID, create a new cart
        final cart = await cartRepository.createCart();
        emit(CartInitialized(cart, isNewCart: true));
      } else {
        // Try to get the cart by ID
        try {
          final cart = await cartRepository.getCartById(cartId);
          emit(CartInitialized(cart, isNewCart: false));
        } catch (e) {
          // If cart retrieval fails, create a new cart
          final cart = await cartRepository.createCart();
          emit(CartInitialized(cart, isNewCart: true));
        }
      }
    } catch (e) {
      emit(CartFailure(e.toString()));
    }
  }

  Future<void> _onCartCleared(
    CartClearedEvent event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());

    try {
      // Create a new empty cart
      final cart = await cartRepository.createCart();
      emit(CartInitialized(cart, isNewCart: true));
    } catch (e) {
      emit(CartFailure(e.toString()));
    }
  }

  Future<void> _onUpdateCartLineItems(
    UpdateCartLineItemsEvent event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());

    try {
      final cart = await cartRepository.updateLineItemsInCart(
        cartId: event.cartId,
        cartLineInputs: event.cartLineInputs,
        reverse: event.reverse,
      );
      emit(CartSuccess(cart));
    } catch (e) {
      emit(CartFailure(e.toString()));
    }
  }
}
