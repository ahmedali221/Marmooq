import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_events.dart';

import '../view_model/cart_states.dart';

class CartScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Shopping Cart')),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (context, state) {
          if (state is CartInitial) {
            context.read<CartBloc>().add(CreateCart());
            return Center(child: CircularProgressIndicator());
          }
          if (state is CartLoading) {
            return Center(child: CircularProgressIndicator());
          }
          if (state is CartError) {
            return Center(child: Text(state.message));
          }
          if (state is CartLoaded && state.cartItems.isEmpty) {
            return Center(child: Text('Cart is empty'));
          }
          if (state is CartLoaded) {
            double total = state.cartItems.fold(0, (sum, item) => sum + (item.price * item.quantity));
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: state.cartItems.length,
                    itemBuilder: (context, index) {
                      final item = state.cartItems[index];
                      return ListTile(
                        title: Text(item.title),
                        subtitle: Text('Quantity: ${item.quantity} | Price: \$${item.price}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.remove),
                              onPressed: () {
                                if (item.quantity > 1) {
                                  context.read<CartBloc>().add(UpdateItemQuantity(lineId: item.id, variantId: item.variantId, title: item.title, price: item.price, newQuantity: item.quantity - 1));
                                } else {
                                  context.read<CartBloc>().add(RemoveItemFromCart(lineId: item.id));
                                }
                              },
                            ),
                            Text('${item.quantity}'),
                            IconButton(
                              icon: Icon(Icons.add),
                              onPressed: () => context.read<CartBloc>().add(UpdateItemQuantity(lineId: item.id, variantId: item.variantId, title: item.title, price: item.price, newQuantity: item.quantity + 1)),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete),
                              onPressed: () => context.read<CartBloc>().add(RemoveItemFromCart(lineId: item.id)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[200],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Total: \$${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ElevatedButton(
                        onPressed: () {
                          // Implement checkout
                        },
                        child: Text('Checkout'),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Center(child: Text('Initialize cart'));
        },
      ),
    );
  }
}
