import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:marmooq/features/products/model/product_model.dart';
import 'package:marmooq/features/products/view_model/products_bloc.dart';
import 'package:marmooq/features/products/view_model/products_event.dart';
import 'package:marmooq/features/products/view_model/products_state.dart';
import 'package:marmooq/features/products/widgets/product_card_widget.dart';
import 'package:marmooq/core/widgets/standard_app_bar.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';

class SearchView extends StatefulWidget {
  const SearchView({super.key});

  @override
  State<SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    // Load initial products for search with smaller limit
    context.read<ProductsBloc>().add(FetchProductsEvent(page: 1, limit: 15));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchTimer?.cancel();
    super.dispose();
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

  List<Product> _searchProducts(List<Map<String, dynamic>> collections) {
    if (_searchQuery.isEmpty) return [];

    List<Product> allProducts = [];

    for (final collection in collections) {
      final List<dynamic> productsList = collection['products'] ?? [];
      for (final productData in productsList) {
        try {
          final Product product = Product.fromJson(
            productData as Map<String, dynamic>,
          );
          allProducts.add(product);
        } catch (e) {
          // Skip invalid products
          continue;
        }
      }
    }

    return allProducts.where((product) {
      return product.name.toLowerCase().contains(_searchQuery) ||
          product.description.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: StandardAppBar(
        backgroundColor: Colors.white,
        title: 'البحث',
        onLeadingPressed: null,
        actions: [],
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: ResponsiveUtils.getResponsivePadding(context),
            color: Colors.white,
            child: Container(
              height: ResponsiveUtils.getResponsiveHeight(context, mobile: 50),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 25),
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  hintText: 'ابحث في المنتجات...',
                  hintStyle: TextStyle(
                    color: Colors.grey[500],
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16),
                  ),
                  prefixIcon: Icon(
                    FeatherIcons.search,
                    color: Colors.grey[500],
                    size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 20),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 25),
                    ),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
                    vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            FeatherIcons.x,
                            color: Colors.grey[500],
                            size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 18),
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
          ),
          Expanded(
            child: BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) {
                  return _buildLoadingState();
                } else if (state is ProductsLoaded) {
                  final searchResults = _searchProducts(state.collections);
                  return _buildSearchResults(searchResults);
                } else if (state is ProductsError) {
                  return _buildErrorState(state);
                }
                return _buildEmptyState();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Product> results) {
    if (_searchQuery.isEmpty) {
      return _buildEmptyState();
    }

    if (results.isEmpty) {
      return _buildNoResultsState();
    }

    return Padding(
      padding: ResponsiveUtils.getResponsivePadding(context),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: ResponsiveUtils.getResponsiveGridCrossAxisCount(context),
          childAspectRatio: ResponsiveUtils.getResponsiveGridChildAspectRatio(context),
          crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
          mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
        ),
        itemCount: results.length,
        cacheExtent: 500, // Cache more items for smoother scrolling
        itemBuilder: (context, index) {
          final product = results[index];
          return ProductCardWidget(key: ValueKey(product.id), product: product);
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
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
                  width: ResponsiveUtils.getResponsiveWidth(context, mobile: 50),
                  height: ResponsiveUtils.getResponsiveHeight(context, mobile: 50),
                  child: CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                    strokeWidth: 4,
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20)),
                Text(
                  'جاري تحميل المنتجات...',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 18),
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
              blurRadius: 30,
              offset: const Offset(0, 15),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: ResponsiveUtils.getResponsivePadding(context),
              decoration: BoxDecoration(
                color: AppColors.brandLight,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                FeatherIcons.search,
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 60),
                color: AppColors.brand,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 28)),
            Text(
              'ابحث عن منتجاتك المفضلة',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24),
                fontWeight: FontWeight.bold,
                color: AppColors.brand,
                fontFamily: 'Tajawal',
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16)),
            Text(
              'استخدم شريط البحث للعثور على المنتجات التي تريدها',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16),
                color: Colors.grey,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
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
              blurRadius: 30,
              offset: const Offset(0, 15),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: ResponsiveUtils.getResponsivePadding(context),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 20),
                ),
              ),
              child: Icon(
                FeatherIcons.search,
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 60),
                color: Colors.grey[400],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 28)),
            Text(
              'لم يتم العثور على نتائج',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 24),
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                fontFamily: 'Tajawal',
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16)),
            Text(
              'جرب البحث بكلمات مختلفة أو تحقق من الإملاء',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16),
                color: Colors.grey[600],
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32)),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              icon: Icon(FeatherIcons.x),
              label: const Text('مسح البحث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24),
                  vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 20),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 60),
                color: Colors.red[400],
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24)),
            Text(
              'حدث خطأ في تحميل المنتجات',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 22),
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12)),
            Text(
              state.failure.message,
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, mobile: 16),
                color: Colors.grey[600],
                height: 1.5,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32)),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ProductsBloc>().add(FetchProductsEvent());
              },
              icon: Icon(FeatherIcons.refreshCw, size: ResponsiveUtils.getResponsiveIconSize(context, mobile: 20)),
              label: Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32),
                  vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
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
}
