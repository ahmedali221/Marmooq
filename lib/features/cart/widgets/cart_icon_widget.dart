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
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(25),
              onTap: () => context.go('/cart'),
              child: Container(
                padding: padding ?? const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white,
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
                      color: iconColor ?? Colors.black87,
                      size: iconSize ?? 22,
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
                            color: badgeColor ?? AppColors.brand,
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
          ),
        );
      },
    );
  }
}
