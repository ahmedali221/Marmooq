import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/models/src/cart/cart.dart';
import 'package:shopify_flutter/models/src/cart/inputs/cart_line_update_input/cart_line_update_input.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:marmooq/features/cart/view_model/cart_states.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:marmooq/core/services/security_service.dart';
import 'package:marmooq/core/widgets/standard_app_bar.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';
import 'package:marmooq/core/widgets/shimmer_widgets.dart';

class CartScreen extends StatefulWidget {
  static const String routeName = '/cart';

  const CartScreen({Key? key}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh cart when app becomes visible (resumed)
    if (state == AppLifecycleState.resumed) {
      _refreshCart();
    }
  }

  void _refreshCart() {
    if (mounted) {
      context.read<CartBloc>().add(const RefreshCartEvent());
    }
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog.adaptive(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(
                  FeatherIcons.alertTriangle,
                  color: Colors.orange,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'تأكيد مسح السلة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
            content: const Text(
              'هل أنت متأكد من أنك تريد مسح جميع العناصر من السلة؟ لا يمكن التراجع عن هذا الإجراء.',
              style: TextStyle(fontFamily: 'Tajawal', fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'إلغاء',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.grey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.read<CartBloc>().add(const CartClearedEvent());
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'مسح السلة',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh cart when dependencies change (e.g., when navigating back to this screen)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshCart();
    });
  }

  Widget _buildCartContent(BuildContext context, Cart cart) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshCart();
      },
      color: AppColors.brand,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: ResponsiveUtils.getResponsiveLayout(
            context: context,
            mobile: ListView(
              padding: ResponsiveUtils.getResponsivePadding(context),
              children: [
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 20,
                  ),
                ),
                if (cart.lines.isEmpty)
                  _buildEmptyCartState()
                else
                  _buildCartItems(cart),
              ],
            ),
            tablet: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveUtils.getResponsiveContainerWidth(
                    context,
                    tabletRatio: 0.8,
                  ),
                ),
                child: ListView(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  children: [
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 20,
                      ),
                    ),
                    if (cart.lines.isEmpty)
                      _buildEmptyCartState()
                    else
                      _buildCartItems(cart),
                  ],
                ),
              ),
            ),
            desktop: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: ResponsiveUtils.getResponsiveContainerWidth(
                    context,
                    desktopRatio: 0.6,
                  ),
                ),
                child: ListView(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  children: [
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 20,
                      ),
                    ),
                    if (cart.lines.isEmpty)
                      _buildEmptyCartState()
                    else
                      _buildCartItems(cart),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartLoadingState() {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshCart();
      },
      color: AppColors.brand,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
            ),
            // Cart header shimmer
            ShimmerWidgets.shimmerBase(
              child: Container(
                margin: EdgeInsets.only(
                  bottom: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 20,
                  ),
                ),
                padding: ResponsiveUtils.getResponsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(
                      context,
                      mobile: 16,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: ResponsiveUtils.getResponsiveWidth(
                        context,
                        mobile: 40,
                      ),
                      height: ResponsiveUtils.getResponsiveHeight(
                        context,
                        mobile: 40,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadius(
                            context,
                            mobile: 12,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 16,
                      ),
                    ),
                    Container(
                      height: ResponsiveUtils.getResponsiveHeight(
                        context,
                        mobile: 18,
                      ),
                      width: ResponsiveUtils.getResponsiveWidth(
                        context,
                        mobile: 120,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      height: ResponsiveUtils.getResponsiveHeight(
                        context,
                        mobile: 24,
                      ),
                      width: ResponsiveUtils.getResponsiveWidth(
                        context,
                        mobile: 30,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadius(
                            context,
                            mobile: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Cart items shimmer
            ...List.generate(
              3,
              (index) => ShimmerWidgets.shimmerBase(
                child: ShimmerWidgets.cartItemShimmer(context),
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24),
            ),
            // Total and checkout button shimmer
            ShimmerWidgets.shimmerBase(
              child: Container(
                padding: ResponsiveUtils.getResponsivePadding(context),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(
                      context,
                      mobile: 16,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          height: ResponsiveUtils.getResponsiveHeight(
                            context,
                            mobile: 18,
                          ),
                          width: ResponsiveUtils.getResponsiveWidth(
                            context,
                            mobile: 80,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: ResponsiveUtils.getResponsiveHeight(
                            context,
                            mobile: 20,
                          ),
                          width: ResponsiveUtils.getResponsiveWidth(
                            context,
                            mobile: 100,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
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
                    Container(
                      height: ResponsiveUtils.getResponsiveHeight(
                        context,
                        mobile: 56,
                      ),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadius(
                            context,
                            mobile: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCartState() {
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
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadius(
                    context,
                    mobile: 20,
                  ),
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
                FeatherIcons.shoppingCart,
                size: ResponsiveUtils.getResponsiveIconSize(
                  context,
                  mobile: 60,
                ),
                color: Colors.white,
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 28),
            ),
            Text(
              'سلتك فارغة',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 24,
                ),
                fontWeight: FontWeight.bold,
                color: AppColors.brand,
                fontFamily: 'Tajawal',
              ),
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
            ),
            Text(
              'أضف منتجات للبدء في التسوق',
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(
                  context,
                  mobile: 16,
                ),
                color: Colors.grey,
                fontFamily: 'Tajawal',
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(
              height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32),
            ),
            // Changed to Column layout
            Column(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadius(
                        context,
                        mobile: 16,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/products');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
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
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FeatherIcons.shoppingBag,
                          color: Colors.white,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 20,
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 12,
                          ),
                        ),
                        Text(
                          'تصفح المنتجات',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 16,
                            ),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 16,
                  ),
                ),
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadius(
                        context,
                        mobile: 16,
                      ),
                    ),
                    border: Border.all(color: AppColors.brandMuted, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      _refreshCart();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
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
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FeatherIcons.refreshCw,
                          color: AppColors.brand,
                          size: ResponsiveUtils.getResponsiveIconSize(
                            context,
                            mobile: 20,
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 12,
                          ),
                        ),
                        Text(
                          'تحديث السلة',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 16,
                            ),
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                            fontFamily: 'Tajawal',
                          ),
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

  Widget _buildCartItems(Cart cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: EdgeInsets.only(
            bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 20),
          ),
          padding: ResponsiveUtils.getResponsivePadding(context),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveSpacing(context, mobile: 10),
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(
                      context,
                      mobile: 12,
                    ),
                  ),
                ),
                child: Icon(
                  Icons.shopping_bag_outlined,
                  color: Colors.white,
                  size: ResponsiveUtils.getResponsiveIconSize(
                    context,
                    mobile: 20,
                  ),
                ),
              ),
              SizedBox(
                width: ResponsiveUtils.getResponsiveSpacing(
                  context,
                  mobile: 16,
                ),
              ),
              Text(
                'عناصر السلة',
                style: TextStyle(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(
                    context,
                    mobile: 18,
                  ),
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Tajawal',
                  color: Color(0xFF00695C),
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 16,
                  ),
                  vertical: ResponsiveUtils.getResponsiveSpacing(
                    context,
                    mobile: 8,
                  ),
                ),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(
                      context,
                      mobile: 20,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brand.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${cart.lines.length}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: ResponsiveUtils.getResponsiveFontSize(
                      context,
                      mobile: 14,
                    ),
                    fontFamily: 'Tajawal',
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8),
        ),
        ...cart.lines.map<Widget>(
          (line) => Card(
            margin: EdgeInsets.only(
              bottom: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
              ),
            ),
            elevation: 3,
            shadowColor: Colors.black.withOpacity(0.1),
            child: Padding(
              padding: ResponsiveUtils.getResponsivePadding(context),
              child: Row(
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getResponsiveBorderRadius(
                        context,
                        mobile: 12,
                      ),
                    ),
                    child: Container(
                      width: ResponsiveUtils.getResponsiveWidth(
                        context,
                        mobile: 90,
                      ),
                      height: ResponsiveUtils.getResponsiveHeight(
                        context,
                        mobile: 90,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadius(
                            context,
                            mobile: 12,
                          ),
                        ),
                      ),
                      child: line.merchandise?.image?.originalSrc != null
                          ? CachedNetworkImage(
                              imageUrl: line.merchandise!.image!.originalSrc,
                              fit: BoxFit.cover,
                              memCacheWidth: 80,
                              memCacheHeight: 80,
                              maxWidthDiskCache: 160,
                              maxHeightDiskCache: 160,
                              fadeInDuration: const Duration(milliseconds: 200),
                              placeholder: (context, url) => Container(
                                color: Colors.grey[200],
                                child: const Center(
                                  child: CircularProgressIndicator.adaptive(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF00695C),
                                    ),
                                  ),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  FeatherIcons.image,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                              ),
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(
                                FeatherIcons.image,
                                color: Colors.grey,
                                size: 30,
                              ),
                            ),
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(
                      context,
                      mobile: 16,
                    ),
                  ),
                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          line.merchandise!.product!.title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context,
                              mobile: 16,
                            ),
                            fontFamily: 'Tajawal',
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 8,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.brandLight,
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.getResponsiveBorderRadius(
                                    context,
                                    mobile: 20,
                                  ),
                                ),
                                border: Border.all(
                                  color: AppColors.brandMuted,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Decrease quantity button
                                  InkWell(
                                    onTap: () {
                                      if (line.quantity! > 1) {
                                        context.read<CartBloc>().add(
                                          UpdateCartLineItemsEvent(
                                            cartId: cart.id,
                                            cartLineInputs: [
                                              CartLineUpdateInput(
                                                id: line.id,
                                                quantity: line.quantity! - 1,
                                                merchandiseId:
                                                    line.merchandise!.id,
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(
                                        ResponsiveUtils.getResponsiveSpacing(
                                          context,
                                          mobile: 6,
                                        ),
                                      ),
                                      child: Icon(
                                        FeatherIcons.minus,
                                        size:
                                            ResponsiveUtils.getResponsiveIconSize(
                                              context,
                                              mobile: 18,
                                            ),
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ),
                                  // Quantity display
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal:
                                          ResponsiveUtils.getResponsiveSpacing(
                                            context,
                                            mobile: 8,
                                          ),
                                      vertical:
                                          ResponsiveUtils.getResponsiveSpacing(
                                            context,
                                            mobile: 6,
                                          ),
                                    ),
                                    child: Text(
                                      '${line.quantity}',
                                      style: TextStyle(
                                        color: AppColors.brand,
                                        fontSize:
                                            ResponsiveUtils.getResponsiveFontSize(
                                              context,
                                              mobile: 14,
                                            ),
                                        fontWeight: FontWeight.w600,
                                        fontFamily: 'Tajawal',
                                      ),
                                    ),
                                  ),
                                  // Increase quantity button
                                  InkWell(
                                    onTap: () {
                                      context.read<CartBloc>().add(
                                        UpdateCartLineItemsEvent(
                                          cartId: cart.id,
                                          cartLineInputs: [
                                            CartLineUpdateInput(
                                              id: line.id,
                                              quantity: line.quantity! + 1,
                                              merchandiseId:
                                                  line.merchandise!.id,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    child: Container(
                                      padding: EdgeInsets.all(
                                        ResponsiveUtils.getResponsiveSpacing(
                                          context,
                                          mobile: 6,
                                        ),
                                      ),
                                      child: Icon(
                                        FeatherIcons.plus,
                                        size:
                                            ResponsiveUtils.getResponsiveIconSize(
                                              context,
                                              mobile: 18,
                                            ),
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                mobile: 8,
                              ),
                            ),
                            Text(
                              'الكمية',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 12,
                                ),
                                fontFamily: 'Tajawal',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Price
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${(line.cost?.amountPerQuantity.amount ?? 0.0).toStringAsFixed(3)} د.ك',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 16,
                          ),
                          color: Color(0xFF00695C),
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 4,
                        ),
                      ),
                      Text(
                        'لكل قطعة',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 12,
                          ),
                          color: Colors.grey[600],
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24),
        ),
        Container(
          padding: ResponsiveUtils.getResponsivePadding(context),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المجموع:',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 18,
                      ),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  Text(
                    '${double.tryParse((cart.cost?.totalAmount.amount ?? "0.00").toString())?.toStringAsFixed(3) ?? "0.000"} د.ك',
                    style: TextStyle(
                      fontSize: ResponsiveUtils.getResponsiveFontSize(
                        context,
                        mobile: 20,
                      ),
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00695C),
                      fontFamily: 'Tajawal',
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
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF00695C), const Color(0xFF26A69A)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(
                    ResponsiveUtils.getResponsiveBorderRadius(
                      context,
                      mobile: 16,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () async {
                    // Fetch data from SecurityService
                    final String? customerAccessToken =
                        await SecurityService.getAccessToken();
                    final Map<String, dynamic>? userData =
                        await SecurityService.getUserData();
                    final String email = userData?['email'] ?? '';
                    final String cartId = cart.id;

                    if (customerAccessToken == null ||
                        customerAccessToken.isEmpty) {
                      context.go('/login');
                      return;
                    }

                    context.go(
                      '/shipment',
                      extra: {
                        'customerAccessToken': customerAccessToken,
                        'cartId': cartId,
                        'email': email,
                      },
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandDark,
                    minimumSize: Size.fromHeight(
                      ResponsiveUtils.getResponsiveHeight(context, mobile: 56),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadius(
                          context,
                          mobile: 16,
                        ),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.payment,
                        color: Colors.white,
                        size: ResponsiveUtils.getResponsiveIconSize(
                          context,
                          mobile: 20,
                        ),
                      ),
                      SizedBox(
                        width: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 12,
                        ),
                      ),
                      Text(
                        'المتابعة إلى الدفع',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 16,
                          ),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontFamily: 'Tajawal',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: StandardAppBar(
          backgroundColor: Colors.white,
          title: 'سلة التسوق',
          onLeadingPressed: null,
          actions: [
            StandardAppBarAction(
              iconColor: AppColors.brandDark,
              icon: FeatherIcons.refreshCw,
              onPressed: () {
                _refreshCart();
              },
            ),
            StandardAppBarAction(
              iconColor: AppColors.brandDark,
              icon: FeatherIcons.trash2,
              onPressed: () {
                _showClearCartDialog(context);
              },
            ),
          ],
          elevation: 0,
          centerTitle: true,
        ),

        body: Container(
          decoration: const BoxDecoration(color: Color(0xFFF6FBFC)),
          child: BlocConsumer<CartBloc, CartState>(
            listener: (context, state) {
              // Cart state listener
            },
            builder: (context, state) {
              if (state is CartInitial) {
                // Load existing cart or create a new one if needed
                context.read<CartBloc>().add(LoadCartEvent());
                return _buildCartLoadingState();
              }
              if (state is CartLoading) {
                return _buildCartLoadingState();
              }
              if (state is CartSuccess) {
                return _buildCartContent(context, state.cart);
              }
              if (state is CartInitialized) {
                return _buildCartContent(context, state.cart);
              }
              if (state is CartFailure) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FeatherIcons.alertCircle,
                        size: 60,
                        color: Colors.red[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'خطأ في تحميل السلة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[600],
                          fontFamily: 'Tajawal',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: ${state.error}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'Tajawal',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _refreshCart,
                        icon: const Icon(FeatherIcons.refreshCw),
                        label: const Text(
                          'إعادة المحاولة',
                          style: TextStyle(fontFamily: 'Tajawal'),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FeatherIcons.shoppingCart,
                      size: 60,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'فشل في تهيئة السلة',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                        fontFamily: 'Tajawal',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
