import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marmooq/features/products/model/product_model.dart';
import 'package:marmooq/features/products/view/collection_details_view.dart';
import 'package:marmooq/features/products/view_model/products_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/features/products/view_model/products_event.dart';
import 'package:marmooq/features/products/view_model/products_state.dart';
import 'package:marmooq/features/products/widgets/product_card_widget.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:marmooq/features/cart/view_model/cart_states.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:marmooq/core/widgets/standard_app_bar.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  late AnimationController _animationController;
  Timer? _refreshTimer;
  Timer? _searchTimer;
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ProductsBloc>().add(FetchProductsEvent(page: 1, limit: 10));
    // Refresh cart state to ensure it's up to date
    _refreshCart();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Add scroll listener for lazy loading
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _loadMoreProducts() {
    final state = context.read<ProductsBloc>().state;
    if (state is ProductsLoaded && state.hasMore && !state.isLoadingMore) {
      context.read<ProductsBloc>().add(
        LoadMoreProductsEvent(page: state.currentPage + 1, limit: 10),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    _refreshTimer?.cancel();
    _searchTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh cart when app resumes (e.g., returning from checkout)
    if (state == AppLifecycleState.resumed) {
      _refreshCart();
    }
  }

  void _refreshCart() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        context.read<CartBloc>().add(const RefreshCartEvent());
      }
    });
  }

  // Method to refresh cart when navigating back to this page
  void refreshCartOnReturn() {
    _refreshCart();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only refresh cart on first load, not on every dependency change
    if (!_hasInitialized) {
      _refreshCart();
      _hasInitialized = true;
    }
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = value.toLowerCase().trim();
        });
      }
    });
  }

  List<Map<String, dynamic>> _filterCollections(
    List<Map<String, dynamic>> collections,
  ) {
    if (_searchQuery.isEmpty) return collections;

    return collections
        .map((collection) {
          final List<dynamic> products = collection['products'] ?? [];
          final filteredProducts = products.where((product) {
            final Product prod = Product.fromJson(
              product as Map<String, dynamic>,
            );
            return prod.name.toLowerCase().contains(_searchQuery) ||
                prod.description.toLowerCase().contains(_searchQuery);
          }).toList();

          return {...collection, 'products': filteredProducts};
        })
        .where((collection) {
          final List<dynamic> products = collection['products'] ?? [];
          final String collectionName =
              collection['collectionName']?.toLowerCase() ?? '';
          return products.isNotEmpty || collectionName.contains(_searchQuery);
        })
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: BlocListener<CartBloc, CartState>(
        listener: (context, state) {
          // Cart state has changed, no need to do anything special here
          // The cart icon widget will automatically update
        },
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: StandardAppBar(
            backgroundColor: Colors.white,
            title: 'مرموق',
            onLeadingPressed: null,
            elevation: 0,
            centerTitle: true,
          ),
          body: Column(
            children: [
              // Welcome message and search bar
              Container(
                color: Colors.white,
                padding: ResponsiveUtils.getResponsivePadding(context),
                child: Column(
                  children: [
                    // Welcome message
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مرحباً! أهلاً بك في مرموق',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                        context,
                                        mobile: 18,
                                      ),
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                'اكتشف منتجاتنا الرائعة',
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                        context,
                                        mobile: 14,
                                      ),
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 20,
                      ),
                    ),
                    // Search bar
                    Container(
                      height: ResponsiveUtils.getResponsiveHeight(
                        context,
                        mobile: 50,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadius(
                            context,
                            mobile: 25,
                          ),
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 16,
                          ),
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.transparent,
                          hintText: 'ابحث هنا...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 16,
                            ),
                          ),
                          prefixIcon: Icon(
                            FeatherIcons.search,
                            color: Colors.grey[500],
                            size: ResponsiveUtils.getResponsiveIconSize(
                              context,
                              mobile: 20,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadius(
                                context,
                                mobile: 25,
                              ),
                            ),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 20,
                            ),
                            vertical: ResponsiveUtils.getResponsiveSpacing(
                              context,
                              mobile: 12,
                            ),
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    FeatherIcons.x,
                                    color: Colors.grey[500],
                                    size: ResponsiveUtils.getResponsiveIconSize(
                                      context,
                                      mobile: 18,
                                    ),
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    _onSearchChanged('');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<ProductsBloc, ProductsState>(
                  builder: (context, state) {
                    if (state is ProductsLoading) {
                      return _buildLoadingState();
                    } else if (state is ProductsLoaded) {
                      final filteredCollections = _filterCollections(
                        state.collections,
                      );
                      if (filteredCollections.isEmpty) {
                        return _buildEmptyState();
                      }
                      return _buildProductsList(filteredCollections);
                    } else if (state is ProductsError) {
                      return _buildErrorState(state);
                    }
                    return const Center(child: Text('لا توجد منتجات'));
                  },
                ),
              ),
            ],
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
            onTap: () {
              // Cart navigation is handled by bottom navigation
            },
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

  // _buildSearchBar removed, integrated into bottom

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        spacing: 10,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: ResponsiveUtils.getResponsivePadding(context),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 24),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: ResponsiveUtils.getResponsiveWidth(
                    context,
                    mobile: 50,
                  ),
                  height: ResponsiveUtils.getResponsiveHeight(
                    context,
                    mobile: 50,
                  ),
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                    strokeWidth: 4,
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 20,
                  ),
                ),
                Text(
                  'جاري تحميل المنتجات...',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 18,
                    ),
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: ResponsiveUtils.getResponsivePadding(context),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? FeatherIcons.search
                  : FeatherIcons.package,
              size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 80),
              color: Colors.grey[400],
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24),
          ),
          Text(
            _searchQuery.isNotEmpty
                ? 'لم يتم العثور على نتائج'
                : 'لا توجد مجموعات متاحة',
            style: TextStyle(
              fontSize: ResponsiveUtils.getResponsiveFontSize(
                context,
                mobile: 20,
              ),
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8),
          ),
          if (_searchQuery.isNotEmpty) ...[
            Text(
              'جرب البحث بكلمات مختلفة',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                ),
                color: Colors.grey[500],
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
            ),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              icon: Icon(FeatherIcons.x),
              label: Text('مسح البحث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[50],
                foregroundColor: Colors.teal[700],
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 24,
                  ),
                  vertical: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 12,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(
                      context,
                      mobile: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(ProductsError state) {
    return Center(
      child: Container(
        margin: ResponsiveUtils.getResponsiveMargin(context),
        padding: ResponsiveUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: ResponsiveUtils.getResponsivePadding(context),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                FeatherIcons.alertCircle,
                size: ResponsiveUtils.getResponsiveIconSize(
                  context,
                  mobile: 60,
                ),
                color: Colors.red[400],
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24),
            ),
            Text(
              'حدث خطأ في تحميل المنتجات',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 22,
                ),
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
            ),
            Text(
              state.failure.message,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                ),
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32),
            ),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ProductsBloc>().add(FetchProductsEvent());
              },
              icon: Icon(
                FeatherIcons.refreshCw,
                size: ResponsiveUtils.getResponsiveIconSize(
                  context,
                  mobile: 20,
                ),
              ),
              label: Text(
                'إعادة المحاولة',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 16,
                  ),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600] ?? const Color(0xFF00695C),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 32,
                  ),
                  vertical: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 16,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(
                      context,
                      mobile: 16,
                    ),
                  ),
                ),
                elevation: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsList(List<Map<String, dynamic>> collections) {
    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        children: [
          ...collections.map((collection) {
            final String collectionName =
                collection['collectionName'] ?? 'مجموعة غير مسماة';
            final List<dynamic> productsList = collection['products'] ?? [];

            if (productsList.isEmpty) return const SizedBox.shrink();

            final previewProducts = productsList.take(6).toList();

            return Container(
              margin: EdgeInsets.only(
                bottom: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: 24,
                ),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 16,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    spreadRadius: 0,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCollectionHeader(collectionName, productsList),
                  _buildProductsHorizontalList(previewProducts),
                  SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 32,
                    ),
                  ), // Increased from 16 to 32
                ],
              ),
            );
          }).toList(),
          // Add loading indicator for lazy loading
          BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              if (state is ProductsLoaded && state.isLoadingMore) {
                return Container(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  child: Center(
                    child: CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.brand,
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionHeader(
    String collectionName,
    List<dynamic> productsList,
  ) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
        ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collectionName,
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 20,
                    ),
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 4,
                  ),
                ),
                Text(
                  '${productsList.length} منتج',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 14,
                    ),
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 12,
              ),
              vertical: ResponsiveUtils.getResponsiveSpacing(
                context,
                mobile: 6,
              ),
            ),
            decoration: BoxDecoration(
              color: AppColors.brand.withOpacity(0.1),
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 20),
              ),
            ),
            child: TextButton(
              onPressed: () {
                context.go(
                  CollectionDetailsView.routeName,
                  extra: {
                    'collectionName': collectionName,
                    'products': productsList
                        .map((p) => Product.fromJson(p as Map<String, dynamic>))
                        .toList(),
                  },
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'عرض الكل',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 14,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 4,
                    ),
                  ),
                  Icon(
                    FeatherIcons.chevronLeft,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 16,
                    ),
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsHorizontalList(List<dynamic> previewProducts) {
    return SizedBox(
      height: ResponsiveUtils.getResponsiveHeight(
        context,
        mobile: 280,
      ), // Fixed height for horizontal scrolling
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
        ),
        itemCount: previewProducts.length,
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, idx) {
          final Product product = Product.fromJson(
            previewProducts[idx] as Map<String, dynamic>,
          );
          return Container(
            width: ResponsiveUtils.getResponsiveCardWidth(
              context,
            ), // Responsive width for each product card
            margin: EdgeInsets.only(
              right: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
              bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
            ), // Increased bottom margin
            child: ProductCardWidget(
              key: ValueKey(product.id),
              product: product,
            ),
          );
        },
      ),
    );
  }
}
