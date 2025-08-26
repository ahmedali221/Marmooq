import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/models/src/cart/cart.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_events.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:traincode/core/services/security_service.dart';

class CartScreen extends StatelessWidget {
  static const String routeName = '/cart';

  const CartScreen({Key? key}) : super(key: key);

  Widget _buildCartContent(BuildContext context, Cart cart) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      children: [
        // Cart ID displayed in a subtle way
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Cart ID: ${cart.id?.substring(0, 8)}...',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        const SizedBox(height: 16),
        if (cart.lines.isEmpty)
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_cart_outlined,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your cart is empty',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Add items to get started',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue Shopping'),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.shopping_bag_outlined, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text(
                      'Your Items',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${cart.lines.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...cart.lines.map<Widget>(
                (line) => Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        // Product Image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: line.merchandise?.image?.originalSrc != null
                                ? CachedNetworkImage(
                                    imageUrl:
                                        line.merchandise!.image!.originalSrc,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Container(
                                          color: Colors.grey[200],
                                          child: const Icon(
                                            Icons.image_not_supported_outlined,
                                            color: Colors.grey,
                                          ),
                                        ),
                                  )
                                : Container(
                                    color: Colors.grey[200],
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      color: Colors.grey,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Product Details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                line.merchandise!.product!.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الكمية: ${line.quantity}',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Price
                        Text(
                          '\$${line.cost?.amountPerQuantity?.amount ?? 0.0}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'المجموع:',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '\$${cart.cost?.totalAmount?.amount ?? "0.00"}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        // Fetch data from SecurityService
                        final String? customerAccessToken =
                            await SecurityService.getAccessToken();
                        final Map<String, dynamic>? userData =
                            await SecurityService.getUserData();
                        final String email = userData?['email'] ?? '';
                        final String cartId = cart.id ?? '';

                        if (customerAccessToken == null ||
                            customerAccessToken.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Please log in to proceed to checkout',
                              ),
                            ),
                          );
                          context.go('/login');
                          return;
                        }

                        context.go(
                          '/shipment',
                          extra: {
                            'customerAccessToken': customerAccessToken,
                            'cartId': cartId,
                            'email': email,
                          },
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Proceed to Checkout',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Shopping Cart',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: () {
              context.go('/products');
            },
            icon: Icon(Icons.arrow_left),
          ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: BlocConsumer<CartBloc, CartState>(
        listener: (context, state) {
          print('DEBUG: CartScreen state changed to: $state');
          if (state is CartSuccess) {
            print(
              'DEBUG: Showing success SnackBar for cart ID: ${state.cart.id}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cart created successfully! ID: ${state.cart.id}',
                ),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state is CartInitialized) {
            print(
              'DEBUG: Cart initialized with ID: ${state.cart.id}, isNewCart: ${state.isNewCart}',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  state.isNewCart
                      ? 'New cart created! ID: ${state.cart.id}'
                      : 'Existing cart loaded! ID: ${state.cart.id}',
                ),
                backgroundColor: Colors.blue,
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (state is CartFailure) {
            print('DEBUG: Showing error SnackBar with message: ${state.error}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: ${state.error}'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is CartInitial) {
            print('DEBUG: CartInitial state, triggering LoadCartEvent');
            // Instead of creating a new cart, we now load an existing cart or create a new one if needed
            context.read<CartBloc>().add(LoadCartEvent());
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CartLoading) {
            print('DEBUG: Rendering CartLoading state');
            return const Center(child: CircularProgressIndicator());
          }
          if (state is CartSuccess) {
            print('DEBUG: Rendering CartSuccess state');
            return _buildCartContent(context, state.cart);
          }
          if (state is CartInitialized) {
            print(
              'DEBUG: Rendering CartInitialized state, isNewCart: ${state.isNewCart}',
            );
            return _buildCartContent(context, state.cart);
          }
          if (state is CartFailure) {
            print('DEBUG: Rendering CartFailure state');
            return Center(child: Text('Error: ${state.error}'));
          }
          print('DEBUG: Rendering default state');
          return const Center(child: Text('Initialize cart Failed'));
        },
      ),
    );
  }
}
