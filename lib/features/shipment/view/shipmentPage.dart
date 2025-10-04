import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/shipment/services/checkout_service.dart';
import 'package:marmooq/features/shipment/view/checkout_webview_screen.dart';
import 'package:marmooq/features/shipment/models/checkout_models.dart';
import 'package:marmooq/features/cart/repository/cart_repository.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marmooq/core/utils/validation_utils.dart';
import 'package:marmooq/core/widgets/standard_app_bar.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';

class ShippingDetailsScreen extends StatefulWidget {
  final String customerAccessToken;
  final String cartId; // Kept for compatibility, but unused
  final String email;

  const ShippingDetailsScreen({
    super.key,
    required this.customerAccessToken,
    required this.cartId,
    required this.email,
  });

  @override
  _ShippingDetailsScreenState createState() => _ShippingDetailsScreenState();
}

class _ShippingDetailsScreenState extends State<ShippingDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _hasCartItems = false;
  List<CartLineInput> _lineItems = [];
  String _selectedCountry = 'Kuwait';

  final CheckoutService _checkoutService = CheckoutService();

  // Simplified form controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Keep original controllers for data mapping
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _countryController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCartLineItems();
    _countryController.text = _selectedCountry;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _countryController.dispose();
    _zipController.dispose();
    super.dispose();
  }

  Future<void> _fetchCartLineItems() async {
    try {
      final cleanCartId = widget.cartId.split('?').first;
      final cart = await ShopifyCart.instance.getCartById(cleanCartId);
      if (cart == null) {
        _showErrorSnackBar('فشل جلب السلة: السلة غير موجودة');
        return;
      }
      setState(() {
        _hasCartItems = (cart.lines).isNotEmpty;
        _lineItems = (cart.lines)
            .map(
              (line) => CartLineInput(
                merchandiseId: line.merchandise!.id,
                quantity: line.quantity!,
              ),
            )
            .toList();
      });
      // Validate merchandise IDs
      final isValid = await _checkoutService.validateCartItems(_lineItems);
      if (!isValid) {
        _showErrorSnackBar('خطأ: منتج غير متوفر في السلة');
        setState(() {
          _hasCartItems = false;
          _lineItems = [];
        });
        return;
      }
      if (!_hasCartItems) {
        _showErrorSnackBar('السلة فارغة، يرجى إضافة منتجات');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في جلب عناصر السلة: $e');
    }
  }

  void _mapFormData() {
    // Split full name into first and last name
    final nameParts = _fullNameController.text.trim().split(' ');
    if (nameParts.isNotEmpty) {
      _firstNameController.text = nameParts.first;
      if (nameParts.length > 1) {
        _lastNameController.text = nameParts.sublist(1).join(' ');
      } else {
        _lastNameController.text = '';
      }
    }

    // Map address to address1 and set defaults for other fields
    _address1Controller.text = _addressController.text.trim();
    _address2Controller.text = '';
    _cityController.text = 'Kuwait City';
    _provinceController.text = 'Kuwait';
    _countryController.text = 'Kuwait';
    _zipController.text = '00000';
  }

  Future<void> _handleCompleteOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Map simplified form data to original structure
    _mapFormData();

    if (widget.customerAccessToken.isEmpty) {
      final error = 'رمز الوصول للعميل فارغ';

      _showErrorSnackBar(error);
      return;
    }

    if (!_hasCartItems || _lineItems.isEmpty) {
      _showErrorSnackBar('السلة فارغة، يرجى إضافة منتجات');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final checkout = await _checkoutService.createCheckout(
        email: widget.email,
        cartId: widget.cartId, // Passed but unused
        customerAccessToken: widget.customerAccessToken,
        lineItems: _lineItems,
      );

      final webUrl = checkout.webUrl;
      if (webUrl.isNotEmpty) {
        // Build prefilled checkout URL with shipping details
        final prefilledUrl = _checkoutService.buildPrefilledCheckoutUrl(
          baseCheckoutUrl: webUrl,
          email: widget.email,
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          address1: _address1Controller.text,
          address2: _address2Controller.text,
          city: _cityController.text,
          province: _provinceController.text,
          country: _countryController.text,
          zip: _zipController.text,
          phone: _phoneController.text,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يتم توجيهك إلى صفحة الدفع...',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.teal,
          ),
        );

        // Push a non-opaque, no-animation route so the WebView runs in the
        // background and the user never sees the checkout screens.
        final route = PageRouteBuilder(
          opaque: false,
          pageBuilder: (context, animation, secondaryAnimation) =>
              CheckoutWebViewScreen(
                checkoutUrl: prefilledUrl,
                checkoutId: checkout.id,
                totalPrice: checkout.totalPrice,
                silentMode: true,
              ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        );

        final result = await Navigator.of(context).push(route);

        // Handle webview result
        if (result is CheckoutResult && result.success) {
          // Clear the cart after successful order
          try {
            final cartRepository = CartRepository();
            // Clear current cart and create a new empty one for future use
            await cartRepository.clearCartAndCreateNew();
            // Emit cart cleared event to update all listeners (including products view)
            if (mounted) {
              context.read<CartBloc>().add(const CartClearedEvent());
            }
          } catch (e) {
            // Don't block navigation if cart clearing fails
          }

          // Navigate to order confirmation page
          if (mounted) {
            context.go(
              '/order-confirmation',
              extra: {
                'message': 'تم إتمام الطلب بنجاح! شكراً لك على التسوق.',
                'checkoutId': checkout.id,
                'webUrl': webUrl,
                'totalPrice': checkout.totalPrice,
              },
            );
          }
        }
      } else {
        throw Exception('لم يتم الحصول على رابط الدفع');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ في إتمام الطلب: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: StandardAppBar(
          backgroundColor: Colors.white,
          title: 'تفاصيل الشحن',
          onLeadingPressed: () => context.go('/cart'),
          showLeading: true,
          elevation: 0,
          centerTitle: true,
        ),
        body: Container(
          decoration: const BoxDecoration(color: AppColors.brandLight),
          child: _isLoading
              ? Center(
                  child: Container(
                    padding: ResponsiveUtils.getResponsivePadding(context),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveBorderRadius(
                          context,
                          mobile: 20,
                        ),
                      ),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator.adaptive(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.brand,
                          ),
                          strokeWidth: 3,
                        ),
                        SizedBox(height: 24),
                        Text(
                          'جاري معالجة طلبك...',
                          style: TextStyle(
                            fontFamily: 'Tajawal',
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 20,
                          ),
                        ),
                        Container(
                          padding: ResponsiveUtils.getResponsivePadding(
                            context,
                          ),
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
                              Container(
                                padding: ResponsiveUtils.getResponsivePadding(
                                  context,
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
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      FeatherIcons.shield,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'يرجى ادخال معلوماتك لإكمال الطلب',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 24,
                                ),
                              ),
                              // Simplified shipping form fields
                              _buildTextField(
                                controller: _fullNameController,
                                label: 'الاسم الكامل',
                                hint: 'اكتب الاسم الكامل',
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'مطلوب'
                                    : null,
                                textInputAction: TextInputAction.next,
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 12,
                                ),
                              ),
                              _buildTextField(
                                controller: _phoneController,
                                label: 'رقم الهاتف',
                                hint: '',
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                maxLength: 8,
                                prefixText: '+965 ',
                                validator: (v) {
                                  final digits = (v ?? '').replaceAll(
                                    RegExp(r'\D'),
                                    '',
                                  );
                                  if (digits.isEmpty) {
                                    return 'يرجى إدخال رقم الهاتف';
                                  }
                                  if (digits.length != 8) {
                                    return 'رقم الهاتف يجب أن يتكون من 8 أرقام';
                                  }
                                  final full = '+965' + digits;
                                  if (!ValidationUtils.isValidKuwaitPhone(
                                    full,
                                  )) {
                                    return 'يرجى إدخال رقم كويتي صالح';
                                  }
                                  return null;
                                },
                                textInputAction: TextInputAction.next,
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 12,
                                ),
                              ),
                              _buildTextField(
                                controller: _addressController,
                                label: 'العنوان الكامل',
                                hint:
                                    'اكتب العنوان الكامل (الشارع، الحي، المنطقة)',
                                validator: (v) => v == null || v.trim().isEmpty
                                    ? 'مطلوب'
                                    : null,
                                textInputAction: TextInputAction.done,
                                maxLines: 3,
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 24,
                                ),
                              ),
                              Container(
                                padding: ResponsiveUtils.getResponsivePadding(
                                  context,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.brandLight,
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.getResponsiveBorderRadius(
                                      context,
                                      mobile: 12,
                                    ),
                                  ),
                                  border: Border.all(
                                    color: AppColors.brandMuted,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      FeatherIcons.info,
                                      color: AppColors.brand,
                                      size: 24,
                                    ),
                                    SizedBox(
                                      width:
                                          ResponsiveUtils.getResponsiveSpacing(
                                            context,
                                            mobile: 12,
                                          ),
                                    ),
                                    const Expanded(
                                      child: Text(
                                        'اضغط للانتقال إلى صفحة الدفع الآمنة',
                                        style: TextStyle(
                                          fontFamily: 'Tajawal',
                                          fontSize: 16,
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textDirection: TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 32,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      AppColors.brand,
                                      AppColors.brandDark,
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    ResponsiveUtils.getResponsiveBorderRadius(
                                      context,
                                      mobile: 16,
                                    ),
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading || !_hasCartItems
                                      ? null
                                      : _handleCompleteOrder,
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: Size.fromHeight(
                                      ResponsiveUtils.getResponsiveHeight(
                                        context,
                                        mobile: 60,
                                      ),
                                    ),
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.getResponsiveBorderRadius(
                                          context,
                                          mobile: 16,
                                        ),
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      vertical:
                                          ResponsiveUtils.getResponsiveSpacing(
                                            context,
                                            mobile: 16,
                                          ),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const CircularProgressIndicator.adaptive(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                          strokeWidth: 2,
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              FeatherIcons.creditCard,
                                              color: Colors.white,
                                              size:
                                                  ResponsiveUtils.getResponsiveIconSize(
                                                    context,
                                                    mobile: 24,
                                                  ),
                                            ),
                                            SizedBox(
                                              width:
                                                  ResponsiveUtils.getResponsiveSpacing(
                                                    context,
                                                    mobile: 12,
                                                  ),
                                            ),
                                            const Text(
                                              'الانتقال إلى الدفع',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                fontFamily: 'Tajawal',
                                                color: Colors.white,
                                              ),
                                              textDirection: TextDirection.rtl,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 24,
                          ),
                        ),
                        Container(
                          padding: ResponsiveUtils.getResponsivePadding(
                            context,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadius(
                                context,
                                mobile: 16,
                              ),
                            ),
                            border: Border.all(
                              color: AppColors.brandMuted,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(
                                      ResponsiveUtils.getResponsiveSpacing(
                                        context,
                                        mobile: 8,
                                      ),
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brandLight,
                                      borderRadius: BorderRadius.circular(
                                        ResponsiveUtils.getResponsiveBorderRadius(
                                          context,
                                          mobile: 12,
                                        ),
                                      ),
                                    ),
                                    child: Icon(
                                      FeatherIcons.shield,
                                      color: AppColors.brand,
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(
                                    width: ResponsiveUtils.getResponsiveSpacing(
                                      context,
                                      mobile: 12,
                                    ),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'معلومات الدفع الآمن',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 16,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.brand,
                                    size: 20,
                                  ),
                                  SizedBox(
                                    width: ResponsiveUtils.getResponsiveSpacing(
                                      context,
                                      mobile: 12,
                                    ),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'سيتم توجيهك إلى صفحة دفع آمنة لإتمام عملية الشراء',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 8,
                                ),
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: AppColors.brand,
                                    size: 20,
                                  ),
                                  SizedBox(
                                    width: ResponsiveUtils.getResponsiveSpacing(
                                      context,
                                      mobile: 12,
                                    ),
                                  ),
                                  const Expanded(
                                    child: Text(
                                      'جميع المعاملات مشفرة ومؤمنة بالكامل',
                                      style: TextStyle(
                                        fontFamily: 'Tajawal',
                                        fontSize: 14,
                                        color: Colors.black87,
                                      ),
                                      textDirection: TextDirection.rtl,
                                      textAlign: TextAlign.right,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    int? maxLength,
    int? maxLines,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            label,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          maxLines: maxLines ?? 1,
          decoration: InputDecoration(
            hintText: hint,
            hintTextDirection: TextDirection.rtl,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            prefixText: prefixText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.brandMuted),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.brandMuted),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
          ),
          validator: validator,
          textDirection: TextDirection.rtl,
        ),
      ],
    );
  }
}
