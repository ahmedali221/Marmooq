import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:marmooq/features/shipment/models/checkout_models.dart';
import 'package:marmooq/features/cart/repository/cart_repository.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

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
  bool _showWebView = false; // Fallback to show WebView if stuck
  Timer? _stuckTimer;
  String _loadingMessage = 'جاري تحميل صفحة الدفع...';
  int _loadingStep = 0;

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

    // Only set a stuck timer when NOT running in silent mode. In silent mode
    // we avoid revealing the WebView or any UI to the user.
    if (!widget.silentMode) {
      _stuckTimer = Timer(const Duration(minutes: 1), () {
        if (!_checkoutCompleted && mounted) {
          setState(() {
            _showWebView = true;
          });
          print(
            'Checkout appears stuck, showing WebView for manual completion',
          );
        }
      });
    }
  }

  void _updateLoadingMessage(String message, {int? step}) {
    if (mounted && !_checkoutCompleted) {
      setState(() {
        _loadingMessage = message;
        if (step != null) _loadingStep = step;
      });
    }
  }

  void _initializeWebView() {
    print('Initializing WebViewController');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..addJavaScriptChannel(
        'CheckoutListener',
        onMessageReceived: (JavaScriptMessage message) {
          print('JavaScript message received: ${message.message}');
          try {
            // Handle checkout completion message from JavaScript
            if (message.message.contains('checkout_complete')) {
              final messageParts = message.message.split(':');
              final completionUrl = messageParts.length > 1
                  ? messageParts[1]
                  : _currentUrl;

              _handleSuccessfulCompletion(completionUrl);
            } else if (message.message.contains('step:')) {
              // Handle progress steps
              final step = int.tryParse(message.message.split(':')[1]) ?? 0;
              final messages = [
                'جاري بدء العملية...',
                'جاري ملء معلومات الشحن...',
                'جاري اختيار طريقة الشحن...',
                'جاري اختيار طريقة الدفع...',
                'جاري إتمام الطلب...',
                'جاري التحقق من الطلب...',
              ];
              if (step < messages.length) {
                _updateLoadingMessage(messages[step], step: step);
              }
            }
          } catch (e) {
            print('Error processing JavaScript message: $e');
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            print('WebView progress: $progress%');
            if (progress == 100) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onPageStarted: (String url) {
            print('Page started: $url');
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            print('Page finished: $url');
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });

            // Check if checkout is completed
            _checkCheckoutCompletion(url);

            // If running invisibly, try to auto-confirm the order flow
            if (widget.silentMode) {
              _attemptAutoConfirm();
              // Try again after a delay
              Future.delayed(const Duration(seconds: 5), () {
                if (!_checkoutCompleted && mounted) {
                  _attemptAutoConfirm();
                }
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
            _handleNonCriticalError(error);
          },
        ),
      );

    print('Loading WebView with URL: ${widget.checkoutUrl}');
    _controller.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  // Attempt to auto-complete the checkout without showing UI.
  // This script tries common Shopify checkout flows:
  // - selects COD if present
  // - clicks primary action buttons across steps
  // - waits between actions to allow navigation
  Future<void> _attemptAutoConfirm() async {
    if (_startedAutoFlow || _checkoutCompleted) return;
    _startedAutoFlow = true;

    _updateLoadingMessage('جاري ملء معلومات الشحن...', step: 1);

    const String script = r'''
      (async function(){
        function wait(ms){ return new Promise(r=>setTimeout(r,ms)); }
        function clickIf(selector){
          const el = document.querySelector(selector);
          if(el){ el.click(); return true; }
          return false;
        }
        function fillIf(selector, value){
          const el = document.querySelector(selector);
          if(el){ 
            el.value = value; 
            el.dispatchEvent(new Event('input', {bubbles: true}));
            el.dispatchEvent(new Event('change', {bubbles: true}));
            return true; 
          }
          return false;
        }
        function selectIf(selector, value){
          const el = document.querySelector(selector);
          if(el){ 
            el.value = value; 
            el.dispatchEvent(new Event('change', {bubbles: true}));
            return true; 
          }
          return false;
        }

        console.log('Starting Shopify checkout auto-confirm process...');
        if (window.CheckoutListener && window.CheckoutListener.postMessage) {
          window.CheckoutListener.postMessage('step:1');
        }
        
        // Wait for page to be fully loaded
        await wait(3000);
        
        // Step 1: Fill shipping information fields
        console.log('Filling shipping information...');
        
        // Fill email field
        fillIf('input[name="checkout[email]"]', 'ahmed@ahme.com');
        fillIf('input[type="email"]', 'ahmed@ahme.com');
        
        // Fill name fields
        fillIf('input[name="checkout[shipping_address][first_name]"]', 'ahmed');
        fillIf('input[name="checkout[shipping_address][last_name]"]', 'ali');
        fillIf('input[placeholder*="الاسم"]', 'ahmed ali');
        fillIf('input[placeholder*="Name"]', 'ahmed ali');
        
        // Fill address fields
        fillIf('input[name="checkout[shipping_address][address1]"]', 'kuwait');
        fillIf('input[placeholder*="العنوان"]', 'kuwait');
        fillIf('input[placeholder*="Address"]', 'kuwait');
        
        // Fill city
        fillIf('input[name="checkout[shipping_address][city]"]', 'Kuwait City');
        fillIf('input[placeholder*="القطعة"]', 'Kuwait City');
        fillIf('input[placeholder*="City"]', 'Kuwait City');
        
        // Fill zip code
        fillIf('input[name="checkout[shipping_address][zip]"]', '00000');
        fillIf('input[placeholder*="منزل"]', '00000');
        fillIf('input[placeholder*="Zip"]', '00000');
        
        // Fill phone
        fillIf('input[name="checkout[shipping_address][phone]"]', '+96555574123');
        fillIf('input[type="tel"]', '+96555574123');
        
        await wait(2000);
        if (window.CheckoutListener && window.CheckoutListener.postMessage) {
          window.CheckoutListener.postMessage('step:2');
        }
        
        // Step 2: Select shipping method (Free Delivery)
        console.log('Selecting shipping method...');
        const shippingSelectors = [
          'input[value*="free" i]',
          'input[value*="توصيل مجاني" i]',
          'input[value*="standard" i]',
          'input[name*="shipping"]',
          'input[type="radio"][name*="shipping"]'
        ];
        
        let shippingSelected = false;
        for (const selector of shippingSelectors) {
          if (clickIf(selector)) {
            console.log('Shipping method selected with selector:', selector);
            shippingSelected = true;
            break;
          }
        }
        
        if (shippingSelected) await wait(1500);
        if (window.CheckoutListener && window.CheckoutListener.postMessage) {
          window.CheckoutListener.postMessage('step:3');
        }
        
        // Step 3: Select payment method (Cash on Delivery)
        console.log('Selecting payment method...');
        const paymentSelectors = [
          'input[value*="cod" i]',
          'input[value*="cash on delivery" i]',
          'input[value*="الدفع عند الاستلام" i]',
          'input[value*="cash_on_delivery" i]',
          'input[name*="payment"]',
          'input[type="radio"][name*="payment"]'
        ];
        
        let paymentSelected = false;
        for (const selector of paymentSelectors) {
          if (clickIf(selector)) {
            console.log('Payment method selected with selector:', selector);
            paymentSelected = true;
            break;
          }
        }
        
        if (paymentSelected) await wait(1500);
        if (window.CheckoutListener && window.CheckoutListener.postMessage) {
          window.CheckoutListener.postMessage('step:4');
        }
        
        // Step 4: Click continue/complete buttons
        console.log('Looking for continue buttons...');
        const continueSelectors = [
          'button[name="button"]',
          'button[type="submit"]',
          'button[data-continue-button]',
          'button.primary',
          'button[class*="continue"]',
          'button[class*="submit"]',
          'input[type="submit"]',
          'button:contains("Continue")',
          'button:contains("Submit")',
          'button:contains("Place order")',
          'button:contains("Complete order")',
          'button:contains("Complete")',
          'button:contains("Pay")',
          'button:contains("إتمام")',
          'button:contains("متابعة")'
        ];
        
        let continueClicked = false;
        for (const selector of continueSelectors) {
          if (clickIf(selector)) {
            console.log('Continue button clicked with selector:', selector);
            continueClicked = true;
            break;
          }
        }
        
        if (continueClicked) await wait(3000);
        if (window.CheckoutListener && window.CheckoutListener.postMessage) {
          window.CheckoutListener.postMessage('step:5');
        }
        
        // Step 5: If still on checkout page, try alternative approaches
        if (window.location.href.includes('/checkouts/') && !window.location.href.includes('/thank_you')) {
          console.log('Still on checkout page, trying alternative approaches...');
          
          // Try clicking any visible buttons with text
          const allButtons = document.querySelectorAll('button, input[type="submit"], input[type="button"]');
          for (const btn of allButtons) {
            if (btn.offsetParent !== null && btn.textContent.trim()) {
              console.log('Trying button:', btn.textContent.trim());
              btn.click();
              await wait(2000);
              break;
            }
          }
          
          // Try form submission
          const forms = document.querySelectorAll('form');
          for (const form of forms) {
            if (form.offsetParent !== null) {
              console.log('Trying form submission');
              form.submit();
              await wait(2000);
              break;
            }
          }
        }
        
        console.log('Auto-confirm process completed');
      })();
    ''';

    try {
      await _controller.runJavaScriptReturningResult(script);
    } catch (e) {
      print('Auto-confirm script error: $e');
      _updateLoadingMessage('جاري معالجة الطلب...', step: 5);
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
      Navigator.of(context).pop(CheckoutResult.cancelled());
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
    _stuckTimer?.cancel();

    // Clear the cart after successful checkout completion
    _clearCartAfterSuccessfulOrder();

    // If running silently, immediately return success to the caller without
    // showing any dialogs. Otherwise show the success dialog as before.
    if (widget.silentMode) {
      if (mounted) {
        Navigator.of(context).pop(
          CheckoutResult.success(
            url: completionUrl,
            checkoutId: widget.checkoutId,
            totalPrice: widget.totalPrice,
            autoRedirect: true,
          ),
        );
      }
    } else {
      _showSuccessDialog(completionUrl);
    }
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
    // Normal interactive flow: show a dialog. In silent mode we shouldn't
    // display dialogs (handled earlier in _handleSuccessfulCompletion).
    if (widget.silentMode) return;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing by tapping outside
      builder: (BuildContext context) {
        // Auto-close the dialog and webview after 3 seconds
        Timer(const Duration(seconds: 3), () {
          if (mounted) {
            Navigator.of(context).pop(); // Close dialog
            Navigator.of(context).pop(
              CheckoutResult.success(
                url: completionUrl,
                checkoutId: widget.checkoutId,
                totalPrice: widget.totalPrice,
                autoRedirect: true,
              ),
            ); // Close checkout view and return to shipment page
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
                  Navigator.of(context).pop(
                    CheckoutResult.success(
                      url: completionUrl,
                      checkoutId: widget.checkoutId,
                      totalPrice: widget.totalPrice,
                      autoRedirect: true,
                    ),
                  ); // Close checkout view
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
    // In silent mode return error immediately without showing UI. Otherwise
    // show an interactive error dialog as before.
    if (widget.silentMode) {
      if (mounted) Navigator.of(context).pop(CheckoutResult.error(message));
      return;
    }

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
              Navigator.of(context).pop(CheckoutResult.error(message));
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
      // Hide the AppBar entirely when running in silent mode so the user
      // doesn't see any checkout UI.
      appBar: widget.silentMode
          ? null
          : AppBar(
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
                if (_showWebView && !_checkoutCompleted)
                  IconButton(
                    icon: const Icon(Icons.check_circle, color: Colors.white),
                    onPressed: () {
                      _showManualCompletionDialog();
                    },
                    tooltip: 'Mark as completed',
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
          // WebView layer - Always keep the WebView mounted so background JS can run
          Opacity(
            opacity: widget.silentMode
                ? 0.0
                : ((widget.silentMode && !_showWebView) ? 0.0 : 1.0),
            child: IgnorePointer(
              ignoring: widget.silentMode && !_showWebView,
              child: WebViewWidget(controller: _controller),
            ),
          ),

          // Enhanced loading overlay for normal mode
          if (!widget.silentMode && _isLoading)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated loading indicator
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1500),
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: const CircularProgressIndicator.adaptive(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF00695C),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _loadingMessage,
                      style: const TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF00695C),
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'الرجاء الانتظار...',
                      style: TextStyle(
                        fontFamily: 'Tajawal',
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ),

          // Silent mode enhanced loading overlay
          if (widget.silentMode && !_checkoutCompleted && !_showWebView)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFF5F5F5)],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated secure icon
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 1000),
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00695C).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline,
                              size: 48,
                              color: Color(0xFF00695C),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 32),

                    // Progress indicator
                    const SizedBox(
                      width: 200,
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFE0E0E0),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00695C),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Main loading message
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        _loadingMessage,
                        style: const TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00695C),
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Subtitle
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 40),
                      child: Text(
                        'نقوم بمعالجة طلبك بشكل آمن\nالرجاء عدم إغلاق التطبيق',
                        style: TextStyle(
                          fontFamily: 'Tajawal',
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                    ),

                    // Security badge
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user,
                            size: 20,
                            color: Color(0xFF00695C),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'عملية آمنة ومشفرة',
                            style: TextStyle(
                              fontFamily: 'Tajawal',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF00695C),
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
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
    // If running silently, return timeout result without showing dialogs.
    if (widget.silentMode) {
      if (mounted) Navigator.of(context).pop(CheckoutResult.timeout());
      return;
    }

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
              Navigator.of(context).pop(CheckoutResult.timeout());
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
    _stuckTimer?.cancel();
    super.dispose();
  }

  void _showManualCompletionDialog() {
    // In silent mode don't prompt the user; assume manual completion will be
    // handled by other means. For safety, treat this as a no-op or direct
    // completion if asked by caller.
    if (widget.silentMode) {
      _handleSuccessfulCompletion(_currentUrl);
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: const Text(
          'تأكيد إتمام الطلب',
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: 'Tajawal', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'هل تم إتمام عملية الدفع بنجاح في صفحة الدفع؟',
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
              _handleSuccessfulCompletion(_currentUrl);
            },
            child: const Text(
              'نعم، تم الإتمام',
              textDirection: TextDirection.rtl,
              style: TextStyle(fontFamily: 'Tajawal', color: Colors.green),
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation() {
    // Silent flows should not show confirmation dialogs; just cancel the
    // checkout silently.
    if (widget.silentMode) {
      if (mounted) Navigator.of(context).pop(CheckoutResult.cancelled());
      return;
    }

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
              Navigator.of(context).pop(CheckoutResult.cancelled());
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
