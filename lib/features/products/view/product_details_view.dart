import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:traincode/features/products/model/product_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_events.dart';
import 'package:traincode/features/cart/view_model/cart_states.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';
import 'package:go_router/go_router.dart';
import 'package:traincode/core/services/security_service.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:traincode/core/constants/app_colors.dart';

class ProductDetailsView extends StatefulWidget {
  final Product product;

  const ProductDetailsView({super.key, required this.product});

  @override
  State<ProductDetailsView> createState() => _ProductDetailsViewState();
}

class _ProductDetailsViewState extends State<ProductDetailsView> {
  late CarouselSliderController _carouselController;
  int _currentImageIndex = 0;
  int _quantity = 1;
  bool _isAddingToCart = false;
  bool _isLoading = true;
  Product? _loadedProduct;

  @override
  void initState() {
    super.initState();
    _carouselController = CarouselSliderController();
    _loadProductDetails();
  }

  Future<void> _loadProductDetails() async {
    // Simulate loading delay for demonstration
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _loadedProduct = widget.product;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    // No need to dispose CarouselSliderController
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingState();
    }

    return BlocListener<CartBloc, CartState>(
      listener: (context, state) {
        if (state is CartFailure) {
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(FeatherIcons.alertCircle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('حدث خطأ: ${state.error}'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );

          // Reset loading state
          setState(() {
            _isAddingToCart = false;
          });
        }
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              // Image at the top
              _buildImageCarousel(),

              // Content below
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),

                          // Enhanced Product Details Container
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(24),
                                topRight: Radius.circular(24),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  spreadRadius: 0,
                                  blurRadius: 10,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                24,
                                20,
                                100,
                              ), // Added bottom padding for cart icon
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Product Name and Price
                                  _buildProductHeader(),

                                  const SizedBox(height: 12),

                                  // Product Description
                                  _buildProductDescription(),

                                  const SizedBox(height: 24),

                                  // Action Buttons
                                  _buildActionButtons(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    if (_loadedProduct!.images.isEmpty) {
      return Container(
        height: 350,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      FeatherIcons.image,
                      size: 48,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد صور متاحة',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سيتم إضافة الصور قريباً',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            // Overlay buttons
            _buildImageOverlayButtons(),
          ],
        ),
      );
    }

    return Container(
      height: 350,
      child: Stack(
        children: [
          // Enhanced Carousel with better shadows
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              child: CarouselSlider.builder(
                carouselController: _carouselController,
                itemCount: _loadedProduct!.images.length,
                itemBuilder: (context, index, realIndex) {
                  return Hero(
                    tag: 'product-image-${_loadedProduct!.id}-$index',
                    child: Container(
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: _loadedProduct!.images[index],
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator.adaptive(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.brand,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'جاري تحميل الصورة...',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[100],
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FeatherIcons.image,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'خطأ في تحميل الصورة',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                options: CarouselOptions(
                  height: 300,
                  viewportFraction: 1.0,
                  enableInfiniteScroll: true,
                  autoPlay: false,
                  enlargeCenterPage: false,
                  onPageChanged: (index, reason) {
                    setState(() {
                      _currentImageIndex = index;
                    });
                  },
                  scrollPhysics: const BouncingScrollPhysics(),
                ),
              ),
            ),
          ),

          // Navigation Arrows
          if (_loadedProduct!.images.length > 1) ...[
            // Previous Arrow
            Positioned(
              left: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_currentImageIndex > 0) {
                      _carouselController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _carouselController.animateToPage(
                        _loadedProduct!.images.length - 1,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      FeatherIcons.chevronLeft,
                      color: Colors.grey[700],
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
            // Next Arrow
            Positioned(
              right: 8,
              top: 0,
              bottom: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () {
                    if (_currentImageIndex < widget.product.images.length - 1) {
                      _carouselController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _carouselController.animateToPage(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      FeatherIcons.chevronRight,
                      color: Colors.grey[700],
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // Image Indicators (Dots)
          if (widget.product.images.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.product.images.length,
                  (index) => GestureDetector(
                    onTap: () {
                      _carouselController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentImageIndex == index ? 28 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentImageIndex == index
                            ? Colors.white
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            spreadRadius: 0,
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Image Counter
          if (widget.product.images.length > 1)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 0,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FeatherIcons.image, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '${_currentImageIndex + 1} / ${widget.product.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Overlay buttons (Back and Heart)
          _buildImageOverlayButtons(),
        ],
      ),
    );
  }

  Widget _buildImageOverlayButtons() {
    return Positioned(
      top: 50, // Below status bar
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: Icon(
                FeatherIcons.chevronLeft,
                color: Colors.black87,
                size: 20,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Cart button
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildCartIcon(),
          ),
        ],
      ),
    );
  }

  Widget _buildCartIcon() {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, cartState) {
        int itemCount = 0;
        if (cartState is CartSuccess) {
          itemCount = cartState.cart.lines.length;
        } else if (cartState is CartInitialized) {
          itemCount = cartState.cart.lines.length;
        }

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => context.go('/cart'),
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    FeatherIcons.shoppingBag,
                    color: Colors.black87,
                    size: 20,
                  ),
                  if (itemCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          itemCount > 99 ? '99+' : itemCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
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

  Widget _buildProductHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Product Name
        Expanded(
          child: Text(
            widget.product.name,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              height: 1.2,
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: 16),
        // Price
        Text(
          '${widget.product.price.toStringAsFixed(2)} د.ك',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.brand,
          ),
        ),
      ],
    );
  }

  Widget _buildProductDescription() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200] ?? Colors.grey, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FeatherIcons.fileText, color: AppColors.brand, size: 18),
              const SizedBox(width: 8),
              const Text(
                'وصف المنتج',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.product.description.isNotEmpty)
            Text(
              widget.product.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.right,
            )
          else
            Text(
              'لا يوجد وصف متاح لهذا المنتج حالياً.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.right,
            ),
        ],
      ),
    );
  }

  Future<void> _handleBuyNow() async {
    setState(() {
      _isAddingToCart = true;
    });

    try {
      // Check if product is available (has a valid variant ID)
      if (_loadedProduct!.variantId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(FeatherIcons.alertCircle, color: Colors.white),
                SizedBox(width: 8),
                Text('المنتج غير متوفر حالياً'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );

        setState(() {
          _isAddingToCart = false;
        });
        return;
      }

      // Get the current cart state
      final cartState = context.read<CartBloc>().state;
      String cartId;

      if (cartState is CartInitialized) {
        cartId = cartState.cart.id!;
      } else if (cartState is CartSuccess) {
        cartId = cartState.cart.id!;
      } else {
        // Create a new cart if none exists
        context.read<CartBloc>().add(const CreateCartEvent());

        // Wait for cart creation by listening to state changes
        await _waitForCartState([CartInitialized, CartSuccess]);
        final newCartState = context.read<CartBloc>().state;

        if (newCartState is CartInitialized) {
          cartId = newCartState.cart.id!;
        } else if (newCartState is CartSuccess) {
          cartId = newCartState.cart.id!;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(FeatherIcons.alertCircle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('فشل في إنشاء السلة'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          setState(() {
            _isAddingToCart = false;
          });
          return;
        }
      }

      // Create cart line input with product variant ID and quantity
      final cartLineInput = CartLineUpdateInput(
        merchandiseId: widget.product.variantId,
        quantity: _quantity,
      );

      // Dispatch add items to cart event
      context.read<CartBloc>().add(
        AddItemsToCartEvent(cartId: cartId, cartLineInputs: [cartLineInput]),
      );

      // Wait for cart update to complete
      await _waitForCartState([CartSuccess]);

      // Get customer access token and email from secure storage
      final customerAccessToken = await SecurityService.getAccessToken();
      final userData = await SecurityService.getUserData();
      final email = userData?['email'] as String?;

      if (customerAccessToken == null || customerAccessToken.isEmpty) {
        // User not logged in, show login prompt
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(FeatherIcons.logIn, color: Colors.white),
                SizedBox(width: 8),
                Text('يرجى تسجيل الدخول للمتابعة إلى الدفع'),
              ],
            ),
            backgroundColor: AppColors.brand,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            action: SnackBarAction(
              label: 'تسجيل الدخول',
              textColor: Colors.white,
              onPressed: () {
                context.go('/login');
              },
            ),
          ),
        );
      } else {
        // Navigate to checkout page
        context.go(
          '/shipment',
          extra: {
            'customerAccessToken': customerAccessToken,
            'cartId': cartId,
            'email': email ?? '',
          },
        );
      }

      // Reset loading state
      setState(() {
        _isAddingToCart = false;
      });
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(FeatherIcons.alertCircle, color: Colors.white),
              const SizedBox(width: 8),
              Text('حدث خطأ: ${e.toString()}'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // Reset loading state on error
      setState(() {
        _isAddingToCart = false;
      });
    }
  }

  // Helper method to wait for specific cart states
  Future<void> _waitForCartState(List<Type> expectedStates) async {
    final completer = Completer<void>();
    late StreamSubscription subscription;

    subscription = context.read<CartBloc>().stream.listen((state) {
      if (expectedStates.any((type) => state.runtimeType == type)) {
        subscription.cancel();
        completer.complete();
      } else if (state is CartFailure) {
        subscription.cancel();
        completer.completeError(state.error);
      }
    });

    // Add timeout to prevent infinite waiting
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        subscription.cancel();
        throw TimeoutException(
          'Cart operation timed out',
          const Duration(seconds: 10),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Action Buttons Row
        Row(
          children: [
            // Add to Cart Button (Smaller, with cart icon)
            Container(
              width: 60,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey[300] ?? Colors.grey,
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isAddingToCart
                      ? null
                      : () async {
                          setState(() {
                            _isAddingToCart = true;
                          });

                          try {
                            // Check if product is available (has a valid variant ID)
                            if (widget.product.variantId == null ||
                                widget.product.variantId.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        FeatherIcons.alertCircle,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text('المنتج غير متوفر حالياً'),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );

                              setState(() {
                                _isAddingToCart = false;
                              });
                              return;
                            }

                            // Get the current cart state
                            final cartState = context.read<CartBloc>().state;
                            String cartId;

                            if (cartState is CartInitialized) {
                              cartId = cartState.cart.id ?? '';
                            } else if (cartState is CartSuccess) {
                              cartId = cartState.cart.id ?? '';
                            } else {
                              // Create a new cart if none exists
                              context.read<CartBloc>().add(
                                const CreateCartEvent(),
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(
                                        FeatherIcons.info,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 8),
                                      Text('جاري إنشاء سلة جديدة...'),
                                    ],
                                  ),
                                  backgroundColor: Colors.blue,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              );
                              return;
                            }

                            // Check if the product is already in the cart
                            bool isDuplicate = false;
                            int existingQuantity = 0;
                            final int maxQuantityAllowed = 10;

                            if (cartState is CartInitialized) {
                              for (final line in cartState.cart.lines) {
                                if (line.merchandise?.id ==
                                    widget.product.variantId) {
                                  isDuplicate = true;
                                  existingQuantity = line.quantity!;
                                  break;
                                }
                              }
                            } else if (cartState is CartSuccess) {
                              for (final line in cartState.cart.lines) {
                                if (line.merchandise?.id ==
                                    widget.product.variantId) {
                                  isDuplicate = true;
                                  existingQuantity = line.quantity!;
                                  break;
                                }
                              }
                            }

                            // Check if adding the new quantity would exceed the maximum allowed
                            if (isDuplicate &&
                                existingQuantity + _quantity >
                                    maxQuantityAllowed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        FeatherIcons.alertTriangle,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'لا يمكن إضافة أكثر من $maxQuantityAllowed قطع من هذا المنتج',
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.brand,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
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
                                  ? existingQuantity + _quantity
                                  : _quantity,
                            );

                            // Dispatch add items to cart event
                            context.read<CartBloc>().add(
                              AddItemsToCartEvent(
                                cartId: cartId,
                                cartLineInputs: [cartLineInput],
                              ),
                            );

                            // Show success message based on whether item was added or updated
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      FeatherIcons.checkCircle,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isDuplicate
                                          ? 'تم تحديث كمية المنتج في السلة'
                                          : 'تم إضافة المنتج إلى السلة بنجاح',
                                    ),
                                  ],
                                ),
                                backgroundColor: AppColors.brand,
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                action: SnackBarAction(
                                  label: 'عرض السلة',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/cart');
                                  },
                                ),
                              ),
                            );

                            // Reset loading state
                            setState(() {
                              _isAddingToCart = false;
                            });
                          } catch (e) {
                            // Show error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(
                                      FeatherIcons.alertCircle,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('حدث خطأ: ${e.toString()}'),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            );

                            // Reset loading state on error
                            setState(() {
                              _isAddingToCart = false;
                            });
                          }
                        },
                  child: Center(
                    child: _isAddingToCart
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator.adaptive(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.black87,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            FeatherIcons.shoppingBag,
                            color: Colors.black87,
                            size: 20,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Buy Now Button (Main button)
            Expanded(
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: _isAddingToCart
                      ? null
                      : () async {
                          await _handleBuyNow();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    _isAddingToCart ? 'جاري المعالجة...' : 'اشتري الآن',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(FeatherIcons.arrowRight, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'تحميل المنتج...',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: Container(
          color: Colors.grey[50],
          child: Column(
            children: [
              // Loading image placeholder
              Container(
                height: 300,
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator.adaptive(),
                ),
              ),
              const SizedBox(height: 20),
              // Loading content placeholder
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 24,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 20,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 60,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
