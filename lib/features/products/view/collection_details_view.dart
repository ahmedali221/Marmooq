import 'package:flutter/material.dart';
import 'package:marmooq/features/products/model/product_model.dart';
import 'package:marmooq/features/products/widgets/product_card_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_states.dart';
import 'package:marmooq/core/widgets/standard_app_bar.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';
import 'package:marmooq/core/widgets/shimmer_widgets.dart';

class CollectionDetailsView extends StatefulWidget {
  /// Route name for navigation
  static const String routeName = '/collection';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeProducts();
  }

  void _initializeProducts() async {
    // Simulate loading delay
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _filteredProducts = widget.products;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: StandardAppBar(
          backgroundColor: Colors.white,
          title: widget.collectionName,
          showLeading: true,
          onLeadingPressed: () => context.go('/products'),
          actions: [_buildCartIcon()],
          elevation: 0,
          centerTitle: true,
        ),
        body: Container(
          color: Colors.grey[50],
          child: _isLoading
              ? _buildLoadingState()
              : _filteredProducts.isEmpty
              ? _buildEmptyState()
              : _buildProductsGrid(),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ShimmerWidgets.shimmerBase(
      child: ShimmerWidgets.gridShimmer(context, itemCount: 6),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            FeatherIcons.package,
            size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 80),
            color: Colors.grey[400],
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
          ),
          Text(
            'لا توجد منتجات متاحة',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 18,
              ),
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
    return ResponsiveUtils.getResponsiveLayout(
      context: context,
      mobile: GridView.builder(
        padding: ResponsiveUtils.getResponsivePadding(context),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(
            context,
          ),
          childAspectRatio: ResponsiveUtils.getResponsiveGridChildAspectRatio(
            context,
          ),
          crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 12,
          ),
          mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
            context,
            mobile: 16,
          ),
        ),
        itemCount: _filteredProducts.length,
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final product = _filteredProducts[index];
          return ProductCardWidget(key: ValueKey(product.id), product: product);
        },
      ),
      tablet: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getResponsiveContainerWidth(
              context,
              tabletRatio: 0.9,
            ),
          ),
          child: GridView.builder(
            padding: ResponsiveUtils.getResponsivePadding(context),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(
                context,
              ),
              childAspectRatio:
                  ResponsiveUtils.getResponsiveGridChildAspectRatio(context),
              crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 12,
              ),
              mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 16,
              ),
            ),
            itemCount: _filteredProducts.length,
            cacheExtent: 500,
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];
              return ProductCardWidget(
                key: ValueKey(product.id),
                product: product,
              );
            },
          ),
        ),
      ),
      desktop: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: ResponsiveUtils.getResponsiveContainerWidth(
              context,
              desktopRatio: 0.8,
            ),
          ),
          child: GridView.builder(
            padding: ResponsiveUtils.getResponsivePadding(context),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(
                context,
              ),
              childAspectRatio:
                  ResponsiveUtils.getResponsiveGridChildAspectRatio(context),
              crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 12,
              ),
              mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 16,
              ),
            ),
            itemCount: _filteredProducts.length,
            cacheExtent: 500,
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];
              return ProductCardWidget(
                key: ValueKey(product.id),
                product: product,
              );
            },
          ),
        ),
      ),
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
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 25),
            ),
            onTap: () => context.go('/cart'),
            child: Container(
              padding: EdgeInsets.all(
                ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 25,
                  ),
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
                    color: Colors.black87,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 22,
                    ),
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: -ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 4,
                      ),
                      top: -ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 4,
                      ),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 6,
                          ),
                          vertical: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 2,
                          ),
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveBorderRadius(
                              context,
                              mobile: 12,
                            ),
                          ),
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        constraints: BoxConstraints(
                          minWidth: ResponsiveUtils.getResponsiveWidth(
                            context,
                            mobile: 18,
                          ),
                          minHeight: ResponsiveUtils.getResponsiveHeight(
                            context,
                            mobile: 18,
                          ),
                        ),
                        child: Text(
                          itemCount > 99 ? '99+' : itemCount.toString(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 10,
                            ),
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
