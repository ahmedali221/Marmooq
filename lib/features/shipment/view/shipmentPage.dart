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
        leading: IconButton(
          onPressed: () {
            context.pop();
          },
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text(
          'إتمام الدفع',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'جاري معالجة طلبك...',
                    style: TextStyle(fontFamily: 'Tajawal'),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Text(
                      'اضغط للانتقال إلى صفحة الدفع الآمنة',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _isLoading || !_hasCartItems
                          ? null
                          : _handleCompleteOrder,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        backgroundColor: Colors.teal,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            )
                          : const Text(
                              'الانتقال إلى الدفع',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Tajawal',
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
