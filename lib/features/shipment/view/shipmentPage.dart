import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/core/services/security_service.dart';
import 'package:traincode/features/shipment/view_model/shipment_bloc.dart';
import 'package:traincode/features/shipment/view_model/shipment_events.dart';
import 'package:traincode/features/shipment/view_model/shipment_states.dart';
import 'package:url_launcher/url_launcher.dart';

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
  final TextEditingController _address1Controller = TextEditingController();
  final TextEditingController _address2Controller = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _countryController = TextEditingController(
    text: 'KW',
  );
  final TextEditingController _provinceController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _companyController = TextEditingController();
  List<CartLineInput> _lineItems = [];
  bool _isDebugMode = kDebugMode;

  @override
  void initState() {
    super.initState();
    if (_isDebugMode) {
      // Autofill test data in debug mode
      _firstNameController.text = 'Ahmed';
      _lastNameController.text = 'Ali';
      _address1Controller.text = '123 Salmiya St';
      _address2Controller.text = 'Apartment 4B';
      _cityController.text = 'Salmiya';
      _provinceController.text = 'HA'; // Valid Kuwait province code (Hawalli)
      _zipController.text = '71523';
      _phoneController.text = '+9651012471460';
      _companyController.text = 'Test Company';
    } else {
      _fetchCustomerDetails();
    }
    _fetchCartLineItems();
  }

  Future<void> _fetchCustomerDetails() async {
    try {
      final userData = await SecurityService.getUserData();
      if (userData != null) {
        setState(() {
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          _phoneController.text = userData['phone'] ?? '';
          if (userData['defaultAddress'] != null) {
            final addr = userData['defaultAddress'];
            _address1Controller.text = addr['address1'] ?? '';
            _address2Controller.text = addr['address2'] ?? '';
            _cityController.text = addr['city'] ?? '';
            _countryController.text = addr['countryCodeV2'] ?? 'KW';
            const validProvinces = ['AH', 'HA', 'JA', 'FA', 'MU', 'KU'];
            _provinceController.text =
                validProvinces.contains(addr['provinceCode'])
                ? addr['provinceCode']
                : '';
            _zipController.text = addr['zip'] ?? '';
            _companyController.text = addr['company'] ?? '';
          }
        });
        if (_isDebugMode) {
          debugPrint('Debug: Fetched customer details: $userData');
        }
      } else {
        if (_isDebugMode) {
          debugPrint('Debug: No user data found in SecurityService');
        }
      }
    } catch (e) {
      if (_isDebugMode) {
        debugPrint('Debug: Error fetching customer details: $e');
      }
      _showErrorSnackBar('خطأ في جلب بيانات المستخدم: $e');
    }
  }

  Future<void> _fetchCartLineItems() async {
    try {
      final cart = await ShopifyCart.instance.getCartById(widget.cartId);
      if (cart == null) {
        if (_isDebugMode) {
          debugPrint('Debug: Cart is null for cartId: ${widget.cartId}');
        }
        _showErrorSnackBar('فشل جلب السلة: السلة غير موجودة');
        return;
      }
      setState(() {
        _lineItems = (cart.lines ?? [])
            .map(
              (line) => CartLineInput(
                merchandiseId: line.merchandise!.id,
                quantity: line.quantity!,
              ),
            )
            .toList();
        if (_isDebugMode) {
          debugPrint(
            'Debug: Fetched ${_lineItems.length} cart items for cartId: ${widget.cartId}',
          );
          for (var item in _lineItems) {
            debugPrint(
              'Debug: CartLineInput - merchandiseId: ${item.merchandiseId}, quantity: ${item.quantity}',
            );
          }
        }
      });
      if (_lineItems.isEmpty) {
        _showErrorSnackBar('السلة فارغة، يرجى إضافة منتجات');
      }
    } catch (e) {
      if (_isDebugMode) {
        debugPrint('Debug: Error fetching cart items: $e');
      }
      _showErrorSnackBar('خطأ في جلب عناصر السلة: $e');
    }
  }

  @override
  void dispose() {
    _address1Controller.dispose();
    _address2Controller.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _provinceController.dispose();
    _zipController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: _isDebugMode
            ? SnackBarAction(
                label: 'تفاصيل',
                textColor: Colors.white,
                onPressed: () {
                  _showDebugDialog(message);
                },
              )
            : null,
      ),
    );
  }

  void _showDebugDialog(String errorMessage) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'تفاصيل الخطأ',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Text(
            errorMessage,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontFamily: 'Tajawal'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
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
        leading: IconButton(
          onPressed: () {
            context.pop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'تفاصيل الشحن',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: BlocListener<ShippingBloc, ShippingState>(
        listener: (context, state) {
          if (state is ShippingSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message, textDirection: TextDirection.rtl),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is ShippingError) {
            final errorMessage = state.error;
            if (_isDebugMode) {
              debugPrint('Debug: ShippingBloc error: $errorMessage');
            }
            _showErrorSnackBar(errorMessage);
          } else if (state is CheckoutCreated) {
            if (_isDebugMode) {
              debugPrint(
                'Debug: Checkout created - ID: ${state.checkoutId}, webUrl: ${state.webUrl}',
              );
              debugPrint(
                'Debug: Available shipping rates: ${state.availableShippingRates}',
              );
            }
            launchUrl(
              Uri.parse(state.webUrl),
              mode: LaunchMode.externalApplication,
            ).then((success) {
              if (!success && _isDebugMode) {
                debugPrint('Debug: Failed to launch URL: ${state.webUrl}');
                _showErrorSnackBar('فشل فتح صفحة الدفع: ${state.webUrl}');
              }
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'يتم توجيهك إلى صفحة الدفع...',
                  textDirection: TextDirection.rtl,
                ),
                backgroundColor: Colors.teal,
              ),
            );
            Future.delayed(const Duration(seconds: 2), () {
              context.go(
                '/order-confirmation',
                extra: {
                  'message':
                      'تم إنشاء الطلب بنجاح! يرجى إكمال الدفع عند الاستلام.',
                  'checkoutId': state.checkoutId,
                },
              );
            });
          }
        },
        child: BlocBuilder<ShippingBloc, ShippingState>(
          builder: (context, state) {
            if (state is ShippingLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildTextField(
                      controller: _firstNameController,
                      label: 'الاسم الأول',
                      validator: (value) =>
                          value!.isEmpty ? 'أدخل الاسم الأول' : null,
                    ),
                    _buildTextField(
                      controller: _lastNameController,
                      label: 'اسم العائلة',
                      validator: (value) =>
                          value!.isEmpty ? 'أدخل اسم العائلة' : null,
                    ),
                    _buildTextField(
                      controller: _address1Controller,
                      label: 'العنوان الأول',
                      validator: (value) =>
                          value!.isEmpty ? 'أدخل العنوان' : null,
                    ),
                    _buildTextField(
                      controller: _address2Controller,
                      label: 'العنوان الثاني (اختياري)',
                    ),
                    _buildTextField(
                      controller: _cityController,
                      label: 'المدينة',
                      validator: (value) =>
                          value!.isEmpty ? 'أدخل المدينة' : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: _countryController.text.isEmpty
                          ? null
                          : _countryController.text,
                      decoration: const InputDecoration(
                        labelText: 'الدولة',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'KW',
                          child: Text(
                            'الكويت',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'SA',
                          child: Text(
                            'السعودية',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'AE',
                          child: Text(
                            'الإمارات',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                      onChanged: (value) => _countryController.text = value!,
                      validator: (value) => value == null ? 'اختر دولة' : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _provinceController.text.isEmpty
                          ? null
                          : _provinceController.text,
                      decoration: const InputDecoration(
                        labelText: 'المحافظة',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'AH',
                          child: Text(
                            'الأحمدي',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'HA',
                          child: Text('حولي', textDirection: TextDirection.rtl),
                        ),
                        DropdownMenuItem(
                          value: 'JA',
                          child: Text(
                            'الجهراء',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'FA',
                          child: Text(
                            'الفروانية',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'MU',
                          child: Text(
                            'مبارك الكبير',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'KU',
                          child: Text(
                            'مدينة الكويت',
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                      ],
                      onChanged: (value) => _provinceController.text = value!,
                      validator: (value) =>
                          value == null ? 'اختر محافظة' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      controller: _zipController,
                      label: 'الرمز البريدي',
                      validator: (value) =>
                          value!.isEmpty ? 'أدخل الرمز البريدي' : null,
                    ),
                    _buildTextField(
                      controller: _phoneController,
                      label: 'رقم الهاتف (اختياري)',
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value != null &&
                            value.isNotEmpty &&
                            !value.startsWith('+965')) {
                          return 'يجب أن يبدأ رقم الهاتف بـ +965';
                        }
                        return null;
                      },
                    ),
                    _buildTextField(
                      controller: _companyController,
                      label: 'الشركة (اختياري)',
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: state is ShippingLoading || _lineItems.isEmpty
                          ? null
                          : () {
                              if (_formKey.currentState!.validate()) {
                                if (widget.customerAccessToken.isEmpty) {
                                  final error = 'رمز الوصول للعميل فارغ';
                                  if (_isDebugMode) debugPrint('Debug: $error');
                                  _showErrorSnackBar(error);
                                  return;
                                }
                                if (_isDebugMode) {
                                  debugPrint(
                                    'Debug: Submitting shipping address with:',
                                  );
                                  debugPrint(
                                    '  customerAccessToken: ${widget.customerAccessToken}',
                                  );
                                  debugPrint('  cartId: ${widget.cartId}');
                                  debugPrint('  email: ${widget.email}');
                                  debugPrint(
                                    '  address1: ${_address1Controller.text}',
                                  );
                                  debugPrint(
                                    '  lineItems count: ${_lineItems.length}',
                                  );
                                }
                                context.read<ShippingBloc>().add(
                                  SubmitShippingAddress(
                                    customerAccessToken:
                                        widget.customerAccessToken,
                                    cartId: widget.cartId,
                                    email: widget.email,
                                    address1: _address1Controller.text,
                                    address2: _address2Controller.text.isEmpty
                                        ? null
                                        : _address2Controller.text,
                                    city: _cityController.text,
                                    country: _countryController.text,
                                    province: _provinceController.text,
                                    zip: _zipController.text,
                                    firstName: _firstNameController.text,
                                    lastName: _lastNameController.text,
                                    phone: _phoneController.text.isEmpty
                                        ? null
                                        : _phoneController.text,
                                    company: _companyController.text.isEmpty
                                        ? null
                                        : _companyController.text,
                                    lineItems: _lineItems,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'إتمام الطلب عند الاستلام',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    if (_isDebugMode) ...[
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          _showDebugDialog(
                            'Debug Info:\n'
                            'customerAccessToken: ${widget.customerAccessToken}\n'
                            'cartId: ${widget.cartId}\n'
                            'email: ${widget.email}\n'
                            'lineItems count: ${_lineItems.length}\n'
                            'Form valid: ${_formKey.currentState?.validate() ?? false}',
                          );
                        },
                        child: const Text(
                          'عرض معلومات التصحيح',
                          style: TextStyle(
                            color: Colors.blue,
                            fontFamily: 'Tajawal',
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          filled: true,
          fillColor: Colors.grey[100],
        ),
        validator: validator,
        keyboardType: keyboardType,
        textDirection: TextDirection.rtl,
        style: const TextStyle(fontFamily: 'Tajawal'),
      ),
    );
  }
}
