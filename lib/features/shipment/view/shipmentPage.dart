import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/features/shipment/repository/shipment_repository.dart';
import 'package:traincode/features/cart/repository/cart_repository.dart';
import 'package:traincode/core/services/security_service.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_events.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:webview_flutter/webview_flutter.dart';

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

  Future<void> _handleCompleteOrder() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

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
        // Navigate to webview screen for checkout
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'يتم توجيهك إلى صفحة الدفع...',
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: Colors.teal,
          ),
        );

        // Navigate to webview checkout screen
        final result = await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CheckoutWebViewScreen(
              checkoutUrl: webUrl,
              checkoutId: checkout['id'] as String,
              totalPrice: checkout['totalPrice'],
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
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: Colors.black87,
            ),
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
                                border: Border.all(
                                  color: Colors.amber[200]!,
                                  width: 1,
                                ),
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
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
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

class CheckoutWebViewScreen extends StatefulWidget {
  final String checkoutUrl;
  final String checkoutId;
  final dynamic totalPrice;

  const CheckoutWebViewScreen({
    super.key,
    required this.checkoutUrl,
    required this.checkoutId,
    required this.totalPrice,
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

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00695C), Color(0xFF26A69A)],
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
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.green,
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
      builder: (context) => AlertDialog(
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
                child: CircularProgressIndicator(
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
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Colors.white,
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
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
        ],
      ),
    );
  }

  void _showTimeoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
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
      builder: (context) => AlertDialog(
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
