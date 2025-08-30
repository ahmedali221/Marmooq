import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/features/shipment/repository/shipment_repository.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isDebugMode = kDebugMode;
  bool _isLoading = false;
  bool _hasCartItems = false;
  List<CartLineInput> _lineItems = [];

  final ShipmentRepository _shipmentRepository = ShipmentRepository();

  @override
  void initState() {
    super.initState();
    _fetchCartLineItems();
  }

  Future<void> _fetchCartLineItems() async {
    try {
      final cleanCartId = widget.cartId.split('?').first;
      final cart = await ShopifyCart.instance.getCartById(cleanCartId);
      if (cart == null) {
        if (_isDebugMode) {
          debugPrint('Debug: Cart is null for cartId: $cleanCartId');
        }
        _showErrorSnackBar('فشل جلب السلة: السلة غير موجودة');
        return;
      }
      setState(() {
        _hasCartItems = (cart.lines ?? []).isNotEmpty;
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
            'Debug: Fetched ${cart.lines?.length ?? 0} cart items for cartId: $cleanCartId',
          );
          for (var line in cart.lines ?? []) {
            debugPrint(
              'Debug: CartLine - merchandiseId: ${line.merchandise?.id}, quantity: ${line.quantity}',
            );
          }
          debugPrint(
            'Debug: Stored lineItems: ${_lineItems.map((item) => 'merchandiseId: ${item.merchandiseId}, quantity: ${item.quantity}').join(', ')}',
          );
        }
      });
      // Validate merchandise IDs
      for (var item in _lineItems) {
        final isValid = await _shipmentRepository.validateMerchandiseId(
          item.merchandiseId,
        );
        if (!isValid) {
          if (_isDebugMode) {
            debugPrint(
              'Debug: Invalid merchandise ID in cart: ${item.merchandiseId}',
            );
          }
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
      if (_isDebugMode) {
        debugPrint('Debug: Error fetching cart items: $e');
      }
      _showErrorSnackBar('خطأ في جلب عناصر السلة: $e');
    }
  }

  Future<void> _handleCompleteOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.customerAccessToken.isEmpty) {
      final error = 'رمز الوصول للعميل فارغ';
      if (_isDebugMode) debugPrint('Debug: $error');
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
      if (_isDebugMode) {
        debugPrint('Debug: Starting complete order process');
        debugPrint('  customerAccessToken: ${widget.customerAccessToken}');
        debugPrint('  cartId: ${widget.cartId}');
        debugPrint('  email: ${widget.email}');
        debugPrint(
          '  lineItems: ${_lineItems.map((item) => 'merchandiseId: ${item.merchandiseId}, quantity: ${item.quantity}').join(', ')}',
        );
      }

      final checkout = await _shipmentRepository.createCheckout(
        email: widget.email,
        cartId: widget.cartId, // Passed but unused
        customerAccessToken: widget.customerAccessToken,
        lineItems: _lineItems,
      );

      final webUrl = checkout['webUrl'] as String?;
      if (webUrl != null) {
        if (_isDebugMode) {
          debugPrint('Debug: Launching checkout URL: $webUrl');
        }

        final launched = await launchUrl(
          Uri.parse(webUrl),
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );

        if (launched) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
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
                'message': 'تم إنشاء الطلب بنجاح! يرجى إكمال الدفع.',
                'checkoutId': checkout['id'],
                'webUrl': webUrl,
                'totalPrice': checkout['totalPrice'],
              },
            );
          });
        } else {
          throw Exception('فشل فتح صفحة الدفع');
        }
      } else {
        throw Exception('لم يتم الحصول على رابط الدفع');
      }
    } catch (e) {
      if (_isDebugMode) {
        debugPrint('Debug: Error completing order: $e');
      }
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
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () {
              context.go('/cart');
            },
            icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black87),
          ),
        ),
        title: const Text(
          'تفاصيل الشحن',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: 'Tajawal',
            fontSize: 22,
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
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F5F5), Color(0xFFE8F5E8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading
            ? Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00695C),
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
                          color: Color(0xFF00695C),
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.1),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00695C),
                                    Color(0xFF26A69A),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.security,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'دفع آمن ومضمون',
                                    style: TextStyle(
                                      fontFamily: 'Tajawal',
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    textDirection: TextDirection.rtl,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.amber[200]!, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.amber[700],
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
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
                            const SizedBox(height: 32),
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00695C),
                                    Color(0xFF26A69A),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.teal.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _isLoading || !_hasCartItems
                                    ? null
                                    : _handleCompleteOrder,
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size.fromHeight(60),
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                        strokeWidth: 2,
                                      )
                                    : const Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.payment,
                                            color: Colors.white,
                                            size: 24,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
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
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.teal.withOpacity(0.2),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.teal.withOpacity(0.1),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.teal[50],
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    Icons.security,
                                    color: Colors.teal[600],
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
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
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.teal[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
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
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: Colors.teal[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
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
    );
  }
}
