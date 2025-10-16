import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/shipment/services/checkout_service.dart';
import 'package:marmooq/features/cart/repository/cart_repository.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:marmooq/core/utils/validation_utils.dart';
import 'package:marmooq/core/widgets/standard_app_bar.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';
import 'package:marmooq/core/services/shopify_auth_service.dart';

class ShippingDetailsScreen extends StatefulWidget {
  final String customerAccessToken;
  final String cartId;
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

  final CheckoutService _checkoutService = CheckoutService();

  // Simplified form controllers - only what we actually need
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCartLineItems();
    _loadUserData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final authService = ShopifyAuthService.instance;
      final user = await authService.currentUser();

      if (user != null && mounted) {
        // Set full name
        if (user.firstName != null || user.lastName != null) {
          final firstName = user.firstName ?? '';
          final lastName = user.lastName ?? '';
          _fullNameController.text = '$firstName $lastName'.trim();
        }

        // Set phone number (remove +965 prefix if present for display)
        if (user.phone != null && user.phone!.isNotEmpty) {
          String phone = user.phone!;
          if (phone.startsWith('+965')) {
            phone = phone.substring(4);
          }
          _phoneController.text = phone;
        }
      }
    } catch (e) {
      debugPrint('Failed to load user data: $e');
    }
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
        _hasCartItems = cart.lines.isNotEmpty;
        _lineItems = cart.lines
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

  Map<String, String> _getFormData() {
    // Split full name into first and last name
    final nameParts = _fullNameController.text.trim().split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    // Format phone number
    String phone = _phoneController.text.trim();
    if (phone.isNotEmpty && !phone.startsWith('+965')) {
      phone = '+965$phone';
    } else if (phone.isEmpty) {
      phone = '+96555544789'; // Demo fallback
    }

    return {
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone,
      'address1': _addressController.text.trim(),
      'address2': '',
      'city': 'Kuwait City',
      'province': 'Kuwait',
      'country': 'Kuwait',
      'zip': '00000',
    };
  }

  Future<void> _handleCompleteOrder() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasCartItems) {
      _showErrorSnackBar('السلة فارغة');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final formData = _getFormData();
      final result = await _checkoutService.completeCODCheckout(
        lineItems: _lineItems,
        cartId: widget.cartId,
        email: widget.email,
        phone: formData['phone']!,
        firstName: formData['firstName']!,
        lastName: formData['lastName']!,
        address1: formData['address1']!,
        customerAccessToken: widget.customerAccessToken,
      );
      if (result.success) {
        final cartRepository = CartRepository();
        await cartRepository.clearCartAndCreateNew();
        context.read<CartBloc>().add(const CartClearedEvent());
        if (result.autoRedirect ?? false) {
          context.go(
            '/order-confirmation',
            extra: {
              'message':
                  'تم إتمام طلبك ${result.checkoutId} بنجاح! الدفع عند الاستلام',
              'checkoutId': result.checkoutId,
              'totalPrice': result.totalPrice,
            },
          );
        }
      } else {
        _showErrorSnackBar(result.error ?? 'خطأ غير متوقع');
      }
    } catch (e) {
      _showErrorSnackBar('خطأ: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
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
              ? _buildLoadingWidget()
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
                        _buildFormContainer(),
                        SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                            context,
                            mobile: 24,
                          ),
                        ),
                        _buildSecurityInfo(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Container(
        padding: ResponsiveUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 20),
          ),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator.adaptive(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
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
    );
  }

  Widget _buildFormContainer() {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24),
          ),
          _buildFormFields(),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 32),
          ),
          _buildSubmitButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 12),
        ),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FeatherIcons.shield, color: Colors.white, size: 24),
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
    );
  }

  Widget _buildFormFields() {
    return Column(
      children: [
        _buildTextField(
          controller: _fullNameController,
          label: 'الاسم الكامل',
          hint: 'اكتب الاسم الكامل',
          validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(
          height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
        ),
        _buildTextField(
          controller: _phoneController,
          label: 'رقم الهاتف',
          hint: '',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 8,
          prefixText: '+965 ',
          validator: (v) {
            final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (digits.isEmpty) return 'يرجى إدخال رقم الهاتف';
            if (digits.length != 8) return 'رقم الهاتف يجب أن يتكون من 8 أرقام';
            if (!ValidationUtils.isValidKuwaitPhone(digits)) {
              return 'يرجى إدخال رقم كويتي صالح (يبدأ بـ 5 أو 6 أو 9)';
            }
            return null;
          },
          textInputAction: TextInputAction.next,
        ),
        SizedBox(
          height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
        ),
        _buildTextField(
          controller: _addressController,
          label: 'العنوان الكامل',
          hint: 'اكتب العنوان الكامل (الشارع، الحي، المنطقة)',
          validator: (v) => v == null || v.trim().isEmpty ? 'مطلوب' : null,
          textInputAction: TextInputAction.done,
          maxLines: 3,
        ),
        SizedBox(
          height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 24),
        ),
        _buildInfoBox(),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: AppColors.brandLight,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 12),
        ),
        border: Border.all(color: AppColors.brandMuted, width: 1),
      ),
      child: Row(
        children: [
          Icon(FeatherIcons.info, color: AppColors.brand, size: 24),
          SizedBox(
            width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
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
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brand, AppColors.brandDark],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
        ),
      ),
      child: ElevatedButton(
        onPressed: _isLoading || !_hasCartItems ? null : _handleCompleteOrder,
        style: ElevatedButton.styleFrom(
          minimumSize: Size.fromHeight(
            ResponsiveUtils.getResponsiveHeight(context, mobile: 60),
          ),
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
            ),
          ),
          padding: EdgeInsets.symmetric(
            vertical: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
          ),
        ),
        child: _isLoading
            ? const CircularProgressIndicator.adaptive(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FeatherIcons.creditCard,
                    color: Colors.white,
                    size: ResponsiveUtils.getResponsiveIconSize(
                      context,
                      mobile: 24,
                    ),
                  ),
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(
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
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getResponsiveBorderRadius(context, mobile: 16),
        ),
        border: Border.all(color: AppColors.brandMuted, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(
                  ResponsiveUtils.getResponsiveSpacing(context, mobile: 8),
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
            height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 16),
          ),
          _buildSecurityItem(
            'سيتم توجيهك إلى صفحة دفع آمنة لإتمام عملية الشراء',
          ),
          SizedBox(
            height: ResponsiveUtils.getResponsiveSpacing(context, mobile: 8),
          ),
          _buildSecurityItem('جميع المعاملات مشفرة ومؤمنة بالكامل'),
        ],
      ),
    );
  }

  Widget _buildSecurityItem(String text) {
    return Row(
      children: [
        Icon(Icons.check_circle_outline, color: AppColors.brand, size: 20),
        SizedBox(
          width: ResponsiveUtils.getResponsiveSpacing(context, mobile: 12),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontFamily: 'Tajawal',
              fontSize: 14,
              color: Colors.black87,
            ),
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
          ),
        ),
      ],
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
