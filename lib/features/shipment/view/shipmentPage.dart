import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/shipment/repository/shipment_repository.dart';
import 'package:marmooq/features/cart/repository/cart_repository.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';
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

  final ShipmentRepository _shipmentRepository = ShipmentRepository();

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
      for (var item in _lineItems) {
        final isValid = await _shipmentRepository.validateMerchandiseId(
          item.merchandiseId,
        );
        if (!isValid) {
          _showErrorSnackBar('خطأ: منتج غير متوفر في السلة');
          setState(() {
            _hasCartItems = false;
            _lineItems = [];
          });
          return;
        }
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
      final checkout = await _shipmentRepository.createCheckout(
        email: widget.email,
        cartId: widget.cartId, // Passed but unused
        customerAccessToken: widget.customerAccessToken,
        lineItems: _lineItems,
      );

      final webUrl = checkout['webUrl'] as String?;
      if (webUrl != null) {
        // Build prefilled checkout URL with shipping details
        final prefilledUrl = _buildPrefilledCheckoutUrl(webUrl);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يتم توجيهك إلى صفحة الدفع...',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.teal,
          ),
        );

        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CheckoutWebViewScreen(
              checkoutUrl: prefilledUrl,
              checkoutId: checkout['id'] as String,
              totalPrice: checkout['totalPrice'],
              silentMode: true,
            ),
          ),
        );

        // Handle webview result
        if (result != null && result['success'] == true) {
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
                'checkoutId': checkout['id'],
                'webUrl': webUrl,
                'totalPrice': checkout['totalPrice'],
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

  String _buildPrefilledCheckoutUrl(String baseCheckoutUrl) {
    final uri = Uri.parse(baseCheckoutUrl);
    final Map<String, String> params = Map<String, String>.from(
      uri.queryParameters,
    );

    void addIfNotEmpty(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        params[key] = value.trim();
      }
    }

    // Shopify checkout prefill parameters
    addIfNotEmpty('checkout[email]', widget.email);
    addIfNotEmpty(
      'checkout[shipping_address][first_name]',
      _firstNameController.text,
    );
    addIfNotEmpty(
      'checkout[shipping_address][last_name]',
      _lastNameController.text,
    );
    addIfNotEmpty(
      'checkout[shipping_address][address1]',
      _address1Controller.text,
    );
    addIfNotEmpty(
      'checkout[shipping_address][address2]',
      _address2Controller.text,
    );
    addIfNotEmpty('checkout[shipping_address][city]', _cityController.text);
    addIfNotEmpty(
      'checkout[shipping_address][province]',
      _provinceController.text,
    );
    addIfNotEmpty(
      'checkout[shipping_address][country]',
      _countryController.text,
    );
    addIfNotEmpty('checkout[shipping_address][zip]', _zipController.text);
    // Normalize Kuwait phone to +965XXXXXXXX pattern before sending
    final String phoneDigits = _phoneController.text.replaceAll(
      RegExp(r'\D'),
      '',
    );
    final String fullKuwaitPhone = phoneDigits.isEmpty
        ? ''
        : '+965' + phoneDigits;
    final String normalizedPhone = ValidationUtils.normalizeKuwaitPhone(
      fullKuwaitPhone,
    );
    addIfNotEmpty('checkout[shipping_address][phone]', normalizedPhone);

    final newUri = uri.replace(queryParameters: params);
    return newUri.toString();
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
          actions: [],
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
                                hint: '+965 5xxxxxxx',
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

class CheckoutWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String checkoutId;
  final dynamic totalPrice;
  final bool silentMode; // if true, keep UI hidden and auto-confirm

  const CheckoutWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.checkoutId,
    required this.totalPrice,
    this.silentMode = false,
  });

  @override
  State<CheckoutWebViewScreen> createState() => _CheckoutWebViewScreenState();
}

class _CheckoutWebViewScreenState extends State<CheckoutWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _currentUrl = '';
  bool _checkoutCompleted = false;
  Timer? _timeoutTimer;
  bool _startedAutoFlow = false;

  @override
  void initState() {
    super.initState();
    _initializeWebView();

    // Set up timeout timer for checkout completion (30 minutes)
    _timeoutTimer = Timer(const Duration(minutes: 30), () {
      if (!_checkoutCompleted && mounted) {
        _showTimeoutDialog();
      }
    });
  }

  void _initializeWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'CheckoutListener',
        onMessageReceived: (JavaScriptMessage message) {
          try {
            // Handle checkout completion message from JavaScript
            if (message.message.contains('checkout_complete')) {
              final messageParts = message.message.split(':');
              final completionUrl = messageParts.length > 1
                  ? messageParts[1]
                  : _currentUrl;

              _handleSuccessfulCompletion(completionUrl);
            }
          } catch (e) {
            // Handle JavaScript message processing errors silently
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() {
                _isLoading = false;
              });
              // Inject console error handling after page loads
              _injectConsoleErrorHandler();
            }
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });

            // Check if checkout is completed
            _checkCheckoutCompletion(url);

            // Inject console monitoring after page finishes loading
            _injectConsoleErrorHandler();

            // If running invisibly, try to auto-confirm the order flow
            if (widget.silentMode) {
              _attemptAutoConfirm();
            }
          },
          onWebResourceError: (WebResourceError error) {
            // Handle non-critical errors gracefully
            _handleNonCriticalError(error);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _injectConsoleErrorHandler() {
    // Inject JavaScript to handle console errors and warnings gracefully
    _controller.runJavaScript('''
      (function() {
        // Store original console methods
        const originalError = console.error;
        const originalWarn = console.warn;
        const originalLog = console.log;
        
        // Override console.error to handle known non-critical errors
        console.error = function(...args) {
          const message = args.join(' ');
          
          // Handle Meta Pixel errors gracefully
          if (message.includes('Meta Pixel') || 
              message.includes('invalid parameter') ||
              message.includes('CLXFaLvT.js')) {
            console.log('Handled Meta Pixel error:', message);
            return; // Suppress the error
          }
          
          // Handle OpenTelemetry metrics export errors
          if (message.includes('OpenTelemetry') || 
              message.includes('metrics export')) {
            console.log('Handled OpenTelemetry error:', message);
            return; // Suppress the error
          }
          
          // Call original error for other cases
          originalError.apply(console, args);
        };
        
        // Override console.warn to handle known warnings
        console.warn = function(...args) {
          const message = args.join(' ');
          
          // Handle Google Maps API loading warnings
          if (message.includes('Google Maps') || 
              message.includes('goo.gle/js-api-loading') ||
              message.includes('maps.googleapis.com')) {
            console.log('Handled Google Maps warning:', message);
            return; // Suppress the warning
          }
          
          // Handle Google Maps Marker deprecation
          if (message.includes('google.maps.Marker') || 
              message.includes('deprecated') ||
              message.includes('AdvancedMarkerElement')) {
            console.log('Handled Maps Marker deprecation:', message);
            return; // Suppress the warning
          }
          
          // Handle ImageReader_JNI buffer warnings
          if (message.includes('ImageReader_JNI') || 
              message.includes('buffer acquisition')) {
            console.log('Handled ImageReader warning:', message);
            return; // Suppress the warning
          }
          
          // Call original warn for other cases
          originalWarn.apply(console, args);
        };
        
        // Monitor for checkout completion indicators
         const checkCompletion = () => {
           // Check for success indicators in the page
           if (document.querySelector('.checkout-success') ||
               document.querySelector('[data-checkout-complete]') ||
               document.querySelector('.order-confirmation') ||
               document.querySelector('.thank-you') ||
               document.querySelector('.order-success') ||
               document.querySelector('[data-order-complete]') ||
               window.location.href.includes('thank_you') ||
               window.location.href.includes('thank-you') ||
               window.location.href.includes('orders/') ||
               window.location.href.includes('checkout/complete') ||
               document.title.includes('Thank you') ||
               document.title.includes('Order confirmation')) {
             
             // Notify Flutter about successful completion
             if (window.CheckoutListener && window.CheckoutListener.postMessage) {
               window.CheckoutListener.postMessage('checkout_complete:' + window.location.href);
             }
           }
         };
        
        // Check completion on DOM changes
        const observer = new MutationObserver(() => {
          checkCompletion();
          
          // Also check for Shopify-specific success elements
          if (document.querySelector('.step__footer') && 
              document.querySelector('.step__footer').textContent.includes('Thank you')) {
            if (window.CheckoutListener && window.CheckoutListener.postMessage) {
              window.CheckoutListener.postMessage('checkout_complete:shopify_thank_you');
            }
          }
        });
        observer.observe(document.body, {
          childList: true,
          subtree: true
        });
        
        // Periodic check as fallback
        setInterval(checkCompletion, 2000);
        
        // Initial check
        setTimeout(checkCompletion, 1000);
      })();
    ''');
  }

  // Attempt to auto-complete the checkout without showing UI.
  // This script tries common Shopify checkout flows:
  // - selects COD if present
  // - clicks primary action buttons across steps
  // - waits between actions to allow navigation
  Future<void> _attemptAutoConfirm() async {
    if (_startedAutoFlow || _checkoutCompleted) return;
    _startedAutoFlow = true;

    const String script = r'''
      (async function(){
        function wait(ms){ return new Promise(r=>setTimeout(r,ms)); }
        function clickIf(selector){
          const el = document.querySelector(selector);
          if(el){ el.click(); return true; }
          return false;
        }
        function tapRadioByText(text){
          const labels=[...document.querySelectorAll('label,span,div')];
          const target=labels.find(l=>l.textContent && l.textContent.toLowerCase().includes(text));
          if(target){
            const r = target.closest('label')?.querySelector('input[type="radio"]') || target.querySelector('input[type="radio"]');
            if(r){ r.click(); r.dispatchEvent(new Event('change',{bubbles:true})); return true; }
          }
          return false;
        }

        // Try to pick Cash on Delivery if present (Arabic/English)
        tapRadioByText('cod') || tapRadioByText('الدفع عند الاستلام') || tapRadioByText('cash on delivery');
        await wait(400);

        // Click continue buttons across steps
        const primarySelectors = [
          'button[name="button" i].step__footer__continue-btn',
          'button[type="submit" i]',
          'button[data-continue-button]',
          'button.primary',
          '.step__footer button',
        ];

        for (let i=0;i<6;i++){
          let clicked=false;
          for(const sel of primarySelectors){
            const btn=document.querySelector(sel);
            if(btn){ btn.click(); clicked=true; break; }
          }
          if(!clicked){
            // Try clicking any visible button that looks like continue/pay
            const btn=[...document.querySelectorAll('button')].find(b=>{
              const t=(b.textContent||'').toLowerCase();
              return /continue|pay|complete|confirm|ادفع|متابعة|تأكيد|إتمام/.test(t);
            });
            if(btn){ btn.click(); }
          }
          await wait(900);

          // If thank-you keywords present, stop.
          if (location.href.includes('thank_you') || location.href.includes('thank-you') || document.title.toLowerCase().includes('thank')) {
            break;
          }
        }
      })();
    ''';

    try {
      await _controller.runJavaScriptReturningResult(script);
    } catch (_) {
      // Ignore scripting errors; completion detection still runs
    }
  }

  void _handleNonCriticalError(WebResourceError error) {
    // List of non-critical error patterns to ignore
    final nonCriticalPatterns = [
      'Meta Pixel',
      'CLXFaLvT.js',
      'web-pixel',
      'OpenTelemetry',
      'maps.googleapis.com',
      'ImageReader_JNI',
      'buffer acquisition',
    ];

    // Check if this is a non-critical error
    final isNonCritical = nonCriticalPatterns.any(
      (pattern) => error.description.contains(pattern),
    );

    if (isNonCritical) {
      // Handle non-critical errors silently
      return;
    }

    // Show error dialog only for critical errors
    _showErrorDialog('خطأ في تحميل الصفحة: ${error.description}');
  }

  void _checkCheckoutCompletion(String url) {
    // Check for Shopify checkout completion patterns
    if (url.contains('/thank_you') ||
        url.contains('/orders/') ||
        url.contains('/checkout/complete') ||
        url.contains('status=complete') ||
        url.contains('/checkouts/') && url.contains('/thank_you') ||
        url.contains('checkout/complete') ||
        url.contains('thank-you')) {
      // Checkout completed successfully - show success dialog and close view
      _handleSuccessfulCompletion(url);
    } else if (url.contains('/cart') ||
        url.contains('cancelled') ||
        url.contains('cancel')) {
      // Checkout was cancelled

      Navigator.of(context).pop({'success': false, 'cancelled': true});
    }

    // Additional check for success indicators in the URL parameters
    final uri = Uri.tryParse(url);
    if (uri != null) {
      final queryParams = uri.queryParameters;
      if (queryParams.containsKey('order_id') ||
          queryParams.containsKey('checkout_token') ||
          queryParams.containsKey('orderId') ||
          queryParams['status'] == 'success' ||
          queryParams['status'] == 'complete' ||
          queryParams['state'] == 'success') {
        _handleSuccessfulCompletion(url);
      }
    }
  }

  void _handleSuccessfulCompletion(String completionUrl) {
    if (_checkoutCompleted) return; // Prevent multiple completions

    _checkoutCompleted = true;
    _timeoutTimer?.cancel();

    // Clear the cart after successful checkout completion
    _clearCartAfterSuccessfulOrder();

    // Show success alert dialog upon completion
    _showSuccessDialog(completionUrl);
  }

  Future<void> _clearCartAfterSuccessfulOrder() async {
    try {
      final cartRepository = CartRepository();
      // Clear current cart and create a new empty one for future use
      await cartRepository.clearCartAndCreateNew();
      // Emit cart cleared event to update all listeners (including products view)
      if (mounted) {
        context.read<CartBloc>().add(const CartClearedEvent());
      }
    } catch (e) {
      // Don't block the success flow if cart clearing fails
    }
  }

  void _showSuccessDialog(String completionUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        // Auto-close the dialog and webview after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop({
              'success': true,
              'url': completionUrl,
              'autoRedirect': true,
            }); // Close checkout view and return to shipment page
          }
        });

        return AlertDialog.adaptive(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B8EA3), Color(0xFF1E9DB2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'تم إتمام الطلب بنجاح!',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 18,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFE6F7FA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Color(0xFFB7E6EF)),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: Color(0xFF1E9DB2),
                      size: 48,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'شكراً لك! تم إتمام عملية الدفع بنجاح.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'تم إرسال رسالة تأكيد إلى بريدك الإلكتروني المسجل.',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'سيتم إغلاق النافذة تلقائياً خلال ثوانٍ...',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00695C), Color(0xFF26A69A)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop({
                    'success': true,
                    'url': completionUrl,
                    'autoRedirect': true,
                  }); // Close checkout view
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'العودة إلى المتجر الآن',
                  style: TextStyle(
                    fontFamily: 'Tajawal',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text(
          'خطأ',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop({'success': false, 'error': message});
            },
            child: const Text(
              'إغلاق',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إتمام الدفع',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
            fontSize: 20,
            color: Colors.white,
          ),
          textDirection: TextDirection.rtl,
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF26A69A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 8,
        shadowColor: Colors.teal.withOpacity(0.3),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () {
            _showExitConfirmation();
          },
        ),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator.adaptive(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              _controller.reload();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Keep webview hidden when silentMode is enabled
          Opacity(
            opacity: widget.silentMode ? 0.0 : 1.0,
            child: IgnorePointer(
              ignoring: widget.silentMode,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator.adaptive(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00695C),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'جاري تحميل صفحة الدفع...',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        color: Color(0xFF00695C),
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ),
          if (widget.silentMode && !_checkoutCompleted)
            // Full-screen loader so user never sees checkout screens
            Container(
              color: Colors.white,
              alignment: Alignment.center,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator.adaptive(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00695C),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'جاري إتمام الطلب بشكل آمن...',
                    style: TextStyle(
                      fontFamily: 'Tajawal',
                      fontSize: 16,
                      color: Color(0xFF00695C),
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog.adaptive(
        title: const Text(
          'انتهت مهلة الدفع',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'انتهت المهلة المحددة لإتمام عملية الدفع. يرجى المحاولة مرة أخرى.',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop({'success': false, 'timeout': true});
            },
            child: const Text(
              'موافق',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _showExitConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text(
          'تأكيد الخروج',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'هل أنت متأكد من أنك تريد الخروج من صفحة الدفع؟ سيتم إلغاء العملية.',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'إلغاء',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Tajawal'),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop({'success': false, 'cancelled': true});
            },
            child: const Text(
              'خروج',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Tajawal', color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
