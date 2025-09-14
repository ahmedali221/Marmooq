import 'package:flutter/material.dart';
import 'package:traincode/features/products/model/product_model.dart';
import 'package:traincode/features/products/widgets/product_card_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';
import 'package:traincode/core/widgets/standard_app_bar.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:traincode/core/constants/app_colors.dart';

class CollectionDetailsView extends StatefulWidget {
  final String collectionName;
  final List<Product> products;

  const CollectionDetailsView({
    super.key,
    required this.collectionName,
    required this.products,
  });

  @override
  State<CollectionDetailsView> createState() => _CollectionDetailsViewState();
}

class _CollectionDetailsViewState extends State<CollectionDetailsView> {
  List<Product> _filteredProducts = [];

  @override
  void initState() {
    super.initState();
    _filteredProducts = widget.products;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: StandardAppBar(
          backgroundColor: Colors.white,
          title: widget.collectionName,
          onLeadingPressed: () => Navigator.of(context).pop(),
          actions: [_buildCartIcon()],
          elevation: 0,
          centerTitle: true,
        ),
        body: Container(
          color: Colors.grey[50],
          child: _filteredProducts.isEmpty
              ? _buildEmptyState()
              : _buildProductsGrid(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FeatherIcons.package, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد منتجات متاحة',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontFamily: 'Tajawal',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 16,
      ),
      itemCount: _filteredProducts.length,
      cacheExtent: 500, // Cache more items for smoother scrolling
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        return ProductCardWidget(key: ValueKey(product.id), product: product);
      },
    );
  }

  Widget _buildCartIcon() {
    return BlocSelector<CartBloc, CartState, int>(
      selector: (state) {
        if (state is CartSuccess) {
          return state.cart.lines.length;
        } else if (state is CartInitialized) {
          return state.cart.lines.length;
        }
        return 0;
      },
      builder: (context, itemCount) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(25),
            onTap: () => context.go('/cart'),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    FeatherIcons.shoppingBag,
                    color: Colors.black87,
                    size: 22,
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          itemCount > 99 ? '99+' : itemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
