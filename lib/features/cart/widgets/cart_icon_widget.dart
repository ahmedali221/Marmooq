import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:traincode/core/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';

class CartIconWidget extends StatelessWidget {
  final Color? iconColor;
  final Color? backgroundColor;
  final Color? badgeColor;
  final double? iconSize;
  final String? tooltip;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const CartIconWidget({
    super.key,
    this.iconColor,
    this.backgroundColor,
    this.badgeColor,
    this.iconSize,
    this.tooltip,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cartState) {
        int itemCount = 0;
        if (cartState is CartSuccess) {
          itemCount = cartState.cart.lines.length;
        } else if (cartState is CartInitialized) {
          itemCount = cartState.cart.lines.length;
        }

        return Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.brandLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              IconButton(
                onPressed: () => context.go('/cart'),
                icon: Icon(
                  FeatherIcons.shoppingBag,
                  color: iconColor ?? AppColors.brand,
                  size: iconSize ?? 24,
                ),
                tooltip: tooltip ?? 'سلة المشتريات',
              ),
              if (itemCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: badgeColor ?? Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      itemCount > 99 ? '99+' : itemCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
