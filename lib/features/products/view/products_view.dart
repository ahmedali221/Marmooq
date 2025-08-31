import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:traincode/features/products/model/product_model.dart';
import 'package:traincode/features/products/view/collection_details_view.dart';
import 'package:traincode/features/products/view_model/products_bloc.dart';
import 'package:traincode/features/products/view_model/products_event.dart';
import 'package:traincode/features/products/view_model/products_state.dart';
import 'package:traincode/features/products/widgets/product_card_widget.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView>
    with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Set<String> _favorites = {};
  String _searchQuery = '';
  bool _isSearchVisible = false;
  late AnimationController _animationController;
  late Animation<double> _searchAnimation;

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(FetchProductsEvent());

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _searchAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (_isSearchVisible) {
        _animationController.forward();
        Future.delayed(const Duration(milliseconds: 100), () {
          _searchFocusNode.requestFocus();
        });
      } else {
        _animationController.reverse();
        _searchController.clear();
        _searchQuery = '';
        _searchFocusNode.unfocus();
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value.toLowerCase().trim();
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
                prod.description?.toLowerCase().contains(_searchQuery) == true;
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FFFE),
        body: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildSliverAppBar(),
            BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) {
                  return SliverFillRemaining(child: _buildLoadingState());
                } else if (state is ProductsLoaded) {
                  final filteredCollections = _filterCollections(
                    state.collections,
                  );
                  if (filteredCollections.isEmpty) {
                    return SliverFillRemaining(child: _buildEmptyState());
                  }
                  return _buildProductsList(filteredCollections);
                } else if (state is ProductsError) {
                  return SliverFillRemaining(child: _buildErrorState(state));
                }
                return const SliverFillRemaining(
                  child: Center(child: Text('لا توجد منتجات')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: _isSearchVisible ? 250.0 : 120.0,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.teal[800],
      title: null,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.teal[50] ?? const Color(0xFFE0F2F1),
                Colors.white,
                Colors.teal[25] ?? const Color(0xFFF1F8E9),
              ],
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 100),
              const Text(
                'المنتجات',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  color: Color(0xFF00695C),
                ),
              ),
              Text(
                'اكتشف مجموعتنا الرائعة',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(70.0),
        child: AnimatedBuilder(
          animation: _searchAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _searchAnimation.value,
              child: Opacity(
                opacity: _searchAnimation.value,
                child: SizedBox(
                  height: 70.0,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Material(
                      elevation: 2,
                      borderRadius: BorderRadius.circular(16),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'ابحث عن المنتجات أو المجموعات...',
                          hintStyle: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 16,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.teal[600],
                            size: 24,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[500],
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
                ),
              ),
            );
          },
        ),
      ),
      actions: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: _isSearchVisible
                      ? Colors.teal[100]
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: Icon(
                    _isSearchVisible ? Icons.close : Icons.search,
                    color: Colors.teal[700],
                  ),
                  onPressed: _toggleSearch,
                  tooltip: _isSearchVisible ? 'إغلاق البحث' : 'البحث',
                ),
              ),
              const SizedBox(width: 4),
              BlocBuilder<CartBloc, CartState>(
                builder: (context, cartState) {
                  int itemCount = 0;
                  if (cartState is CartSuccess) {
                    itemCount = cartState.cart.lines.length;
                  } else if (cartState is CartInitialized) {
                    itemCount = cartState.cart.lines.length;
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.teal[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        IconButton(
                          onPressed: () => context.go('/cart'),
                          icon: Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.teal[700],
                          ),
                          tooltip: 'سلة المشتريات',
                        ),
                        if (itemCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
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
              ),
            ],
          ),
        ),
      ],
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.15),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              children: [
                SizedBox(
                  width: 50,
                  height: 50,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.teal[600]!,
                    ),
                    strokeWidth: 4,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'جاري تحميل المنتجات...',
                  style: TextStyle(
                    fontSize: 18,
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty
                  ? Icons.search_off
                  : Icons.inventory_2_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty
                ? 'لم يتم العثور على نتائج'
                : 'لا توجد مجموعات متاحة',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isNotEmpty) ...[
            Text(
              'جرب البحث بكلمات مختلفة',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('مسح البحث'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[50],
                foregroundColor: Colors.teal[700],
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
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
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'حدث خطأ في تحميل المنتجات',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.grey[800],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              state.failure.message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                context.read<ProductsBloc>().add(FetchProductsEvent());
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: const Text(
                'إعادة المحاولة',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal[600] ?? const Color(0xFF00695C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
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
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final collection = collections[index];
        final String collectionName =
            collection['collectionName'] ?? 'مجموعة غير مسماة';
        final List<dynamic> productsList = collection['products'] ?? [];

        if (productsList.isEmpty) return const SizedBox.shrink();

        final previewProducts = productsList.take(10).toList();

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCollectionHeader(collectionName, productsList),
              _buildProductsHorizontalList(previewProducts),
              const SizedBox(height: 16),
            ],
          ),
        );
      }, childCount: collections.length),
    );
  }

  Widget _buildCollectionHeader(
    String collectionName,
    List<dynamic> productsList,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Colors.teal[50] ?? const Color(0xFFE0F2F1), Colors.white],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
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
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal[800],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${productsList.length} منتج',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.teal[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CollectionDetailsView(
                      collectionName: collectionName,
                      products: productsList
                          .map(
                            (p) => Product.fromJson(p as Map<String, dynamic>),
                          )
                          .toList(),
                    ),
                  ),
                );
              },
              icon: Icon(
                Icons.arrow_back_ios,
                size: 16,
                color: Colors.teal[700],
              ),
              label: Text(
                'عرض الكل',
                style: TextStyle(
                  color: Colors.teal[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsHorizontalList(List<dynamic> previewProducts) {
    return SizedBox(
      height: 400,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: previewProducts.length,
        itemBuilder: (context, idx) {
          final Product product = Product.fromJson(
            previewProducts[idx] as Map<String, dynamic>,
          );
          final isFavorite = _favorites.contains(product.id.toString());
          return Padding(
            padding: const EdgeInsets.only(left: 16),
            child: SizedBox(
              width: 200,
              child: ProductCardWidget(
                product: product,
                isFavorite: isFavorite,
                onToggleFavorite: (p) {
                  setState(() {
                    if (_favorites.contains(p.id.toString())) {
                      _favorites.remove(p.id.toString());
                    } else {
                      _favorites.add(p.id.toString());
                    }
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
