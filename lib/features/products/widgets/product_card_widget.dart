import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:marmooq/features/cart/view_model/cart_states.dart';
import 'package:marmooq/features/products/model/product_model.dart';

class ProductCardWidget extends StatefulWidget {
  final Product product;

  const ProductCardWidget({super.key, required this.product});

  @override
  State<ProductCardWidget> createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<ProductCardWidget>
    with AutomaticKeepAliveClientMixin {
  bool _isAddingToCart = false;

  @override
  bool get wantKeepAlive => true;

  Future<void> _addToCart() async {
    // Check if product is available (has a valid variant ID)
    if (widget.product.variantId.isEmpty) {
      _showSnackBar('المنتج غير متوفر حالياً', Colors.red, Icons.error_outline);
      return;
    }

    setState(() {
      _isAddingToCart = true;
    });

    try {
      // Get the current cart state
      final cartState = context.read<CartBloc>().state;
      String cartId;

      if (cartState is CartInitialized) {
        cartId = cartState.cart.id;
      } else if (cartState is CartSuccess) {
        cartId = cartState.cart.id;
      } else {
        // Create a new cart if none exists
        context.read<CartBloc>().add(const CreateCartEvent());
        _showSnackBar(
          'جاري إنشاء سلة جديدة...',
          Colors.blue,
          Icons.info_outline,
        );
        setState(() {
          _isAddingToCart = false;
        });
        return;
      }

      // Check if the product is already in the cart
      bool isDuplicate = false;
      int existingQuantity = 0;
      const int maxQuantityAllowed = 10;
      const int quantityToAdd = 1;

      if (cartState is CartInitialized) {
        for (final line in cartState.cart.lines) {
          if (line.merchandise?.id == widget.product.variantId) {
            isDuplicate = true;
            existingQuantity = line.quantity!;
            break;
          }
        }
      } else if (cartState is CartSuccess) {
        for (final line in cartState.cart.lines) {
          if (line.merchandise?.id == widget.product.variantId) {
            isDuplicate = true;
            existingQuantity = line.quantity!;
            break;
          }
        }
      }

      // Check if adding the new quantity would exceed the maximum allowed
      if (isDuplicate &&
          existingQuantity + quantityToAdd > maxQuantityAllowed) {
        _showSnackBar(
          'لا يمكن إضافة أكثر من $maxQuantityAllowed قطع من هذا المنتج',
          AppColors.brand,
          Icons.warning_amber_outlined,
        );
        setState(() {
          _isAddingToCart = false;
        });
        return;
      }

      // Create cart line input with product variant ID and quantity
      final cartLineInput = CartLineUpdateInput(
        merchandiseId: widget.product.variantId,
        quantity: isDuplicate
            ? existingQuantity + quantityToAdd
            : quantityToAdd,
      );

      // Dispatch add items to cart event
      context.read<CartBloc>().add(
        AddItemsToCartEvent(cartId: cartId, cartLineInputs: [cartLineInput]),
      );

      // Show success message
      _showSnackBar(
        isDuplicate
            ? 'تم تحديث كمية المنتج في السلة'
            : 'تم إضافة المنتج إلى السلة بنجاح',
        AppColors.brand,
        Icons.check_circle_outline,
      );
    } catch (e) {
      _showSnackBar(
        'حدث خطأ أثناء إضافة المنتج إلى السلة',
        Colors.red,
        Icons.error_outline,
      );
    } finally {
      setState(() {
        _isAddingToCart = false;
      });
    }
  }

  void _showSnackBar(String message, Color backgroundColor, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return GestureDetector(
      onTap: () {
        context.go('/product-details', extra: widget.product);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 5,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.product.images.isNotEmpty
                          ? widget.product.images.first
                          : 'https://via.placeholder.com/200x200',
                      fit: BoxFit.cover,
                      memCacheWidth: 200,
                      memCacheHeight: 200,
                      maxWidthDiskCache: 400,
                      maxHeightDiskCache: 400,
                      fadeInDuration: const Duration(milliseconds: 200),
                      placeholder: (context, url) => Container(
                        color: Colors.grey[50],
                        child: Center(
                          child: CircularProgressIndicator.adaptive(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.brand,
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[50],
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          size: 50,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize:
                          MainAxisSize.min, // Use minimum space needed
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14, // Reduced font size
                            height: 1.2, // Reduced line height
                          ),
                          maxLines: 1, // Limit to 1 line to prevent overflow
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8), // Reduced spacing
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4, // Reduced padding
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brandLight,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${widget.product.price.toStringAsFixed(2)} د.ك',
                                style: TextStyle(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13, // Reduced font size
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isAddingToCart ? null : _addToCart,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: _isAddingToCart
                                      ? Colors.grey[200]
                                      : Colors.grey[50],
                                  shape: BoxShape.circle,
                                ),
                                child: _isAddingToCart
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child:
                                            CircularProgressIndicator.adaptive(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.brand,
                                                  ),
                                            ),
                                      )
                                    : Icon(
                                        Icons.add_shopping_cart_outlined,
                                        size: 16,
                                        color: AppColors.brand,
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
