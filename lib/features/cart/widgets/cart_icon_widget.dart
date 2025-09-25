import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_states.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';

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
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 25),
              ),
              onTap: () => context.go('/cart'),
              child: Container(
                padding: padding ?? EdgeInsets.all(
                  ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
                ),
                decoration: BoxDecoration(
                  color: backgroundColor ?? Colors.white,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 25),
                  ),
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
                      size: iconSize ?? ResponsiveUtils.getResponsiveIconSize(context, mobile: 22),
                    ),
                    if (itemCount > 0)
                      Positioned(
                        right: -ResponsiveUtils.getResponsiveSpacing(context, mobile: 4),
                        top: -ResponsiveUtils.getResponsiveSpacing(context, mobile: 4),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 6),
                            vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 2),
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor ?? AppColors.brand,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 12),
                            ),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: BoxConstraints(
                            minWidth: ResponsiveUtils.getResponsiveWidth(context, mobile: 18),
                            minHeight: ResponsiveUtils.getResponsiveHeight(context, mobile: 18),
                          ),
                          child: Text(
                            itemCount > 99 ? '99+' : itemCount.toString(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 10),
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
