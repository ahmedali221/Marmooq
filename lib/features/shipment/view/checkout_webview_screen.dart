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

  void _updateLoadingMessage(String message) {
    if (mounted && !_checkoutCompleted) {
      setState(() {
        _loadingMessage = message;
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
                _updateLoadingMessage(messages[step]);
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

    _updateLoadingMessage('جاري ملء معلومات الشحن...');

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
            // Clear the field first
            el.value = '';
            el.focus();
            
            // Set the value
            el.value = value; 
            
            // Trigger events to ensure form validation
            el.dispatchEvent(new Event('input', {bubbles: true}));
            el.dispatchEvent(new Event('change', {bubbles: true}));
            el.dispatchEvent(new Event('blur', {bubbles: true}));
            
            // Special handling for phone field with email ID
            if (selector === 'input[id="email"]' && value && !value.includes('@')) {
              console.log('Filling phone field (with email ID) with value:', value);
              // Additional validation for phone field
              el.dispatchEvent(new Event('keyup', {bubbles: true}));
            }
            
            console.log('Field filled:', selector, 'with value:', value);
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
        
        // Extract URL parameters for form data
        const urlParams = new URLSearchParams(window.location.search);
        console.log('URL Parameters:', Object.fromEntries(urlParams.entries()));
        
        // Step 1: Fill shipping information fields
        console.log('Filling shipping information...');
        
        // Extract form data from URL parameters
        const email = urlParams.get('checkout[email]') || '';
        const firstName = urlParams.get('checkout[shipping_address][first_name]') || '';
        const lastName = urlParams.get('checkout[shipping_address][last_name]') || '';
        const phone = urlParams.get('checkout[shipping_address][phone]') || '';
        const address1 = urlParams.get('checkout[shipping_address][address1]') || '';
        const city = urlParams.get('checkout[shipping_address][city]') || '';
        const province = urlParams.get('checkout[shipping_address][province]') || '';
        const country = urlParams.get('checkout[shipping_address][country]') || '';
        const zip = urlParams.get('checkout[shipping_address][zip]') || '';
        
        console.log('Extracted form data:', { email, firstName, lastName, phone, address1, city, province, country, zip });
        
        // Debug: Log all available URL parameters
        console.log('All URL parameters:', Object.fromEntries(urlParams.entries()));
        
        // Debug: Scan all form fields on the page
        console.log('Scanning all form fields on the page...');
        const allInputs = document.querySelectorAll('input, textarea, select');
        allInputs.forEach((input, index) => {
          const id = input.id || 'no-id';
          const name = input.name || 'no-name';
          const type = input.type || 'no-type';
          const placeholder = input.placeholder || 'no-placeholder';
          const value = input.value || 'no-value';
          console.log(`Field ${index + 1}: id="${id}", name="${name}", type="${type}", placeholder="${placeholder}", value="${value}"`);
        });
        
        // Fill email field
        // First try to get email from any pre-filled fields on the page
        let emailToUse = email;
        if (!emailToUse) {
          const preFilledEmailFields = document.querySelectorAll('input[value*="@"]');
          for (const field of preFilledEmailFields) {
            const value = field.value;
            if (value && value.includes('@') && value.includes('.')) {
              emailToUse = value;
              console.log('Found pre-filled email:', emailToUse);
              break;
            }
          }
        }
        
        const emailSelectors = [
          'input[name="checkout[email]"]',
          'input[type="email"]',
          'input[placeholder*="email" i]',
          'input[placeholder*="بريد" i]',
          'input[data-testid*="email"]',
          'input[aria-label*="email" i]',
          // Additional selectors for Shopify checkout
          'input[name="checkout[contact_email]"]',
          'input[name="checkout[billing_address][email]"]',
          'input[name="checkout[shipping_address][email]"]',
          'input[data-testid="email"]',
          'input[data-testid="contact-email"]'
        ];
        
        let emailFilled = false;
        for (const selector of emailSelectors) {
          const element = document.querySelector(selector);
          if (element) {
            console.log('Found email field with selector:', selector, 'Current value:', element.value);
            if (fillIf(selector, emailToUse)) {
              console.log('Email filled with selector:', selector);
              emailFilled = true;
              break;
            }
          }
        }
        
        // If still not filled, try to find any input that might be the email field
        if (!emailFilled) {
          console.log('Trying to find email field by scanning all inputs...');
          const allInputs = document.querySelectorAll('input');
          for (const input of allInputs) {
            const id = input.id || '';
            const name = input.name || '';
            const placeholder = input.placeholder || '';
            const ariaLabel = input.getAttribute('aria-label') || '';
            const type = input.type || '';
            
            // Check if this looks like an email field
            if (type === 'email' || id.includes('email') || name.includes('email') || 
                placeholder.toLowerCase().includes('email') || 
                placeholder.includes('بريد') ||
                ariaLabel.toLowerCase().includes('email') ||
                ariaLabel.includes('بريد')) {
              console.log('Found potential email field:', {id, name, placeholder, ariaLabel, type});
              if (fillIf('#' + id, emailToUse) || fillIf('[name="' + name + '"]', emailToUse)) {
                console.log('Email filled with fallback selector');
                emailFilled = true;
                break;
              }
            }
          }
        }
        
        // Fill phone field (this is the critical one)
        // If phone is not in URL parameters, try to get it from the customer profile update
        let phoneToUse = phone;
        if (!phoneToUse) {
          // Try to extract phone from other sources or use a default
          phoneToUse = '+96556642315'; // Fallback phone number
          console.log('Phone not found in URL parameters, using fallback:', phoneToUse);
        }
        
        // Also try to get phone from any pre-filled fields on the page
        if (!phoneToUse || phoneToUse === '+96556642315') {
          const preFilledPhoneFields = document.querySelectorAll('input[value*="+965"], input[value*="965"]');
          for (const field of preFilledPhoneFields) {
            const value = field.value;
            if (value && value.includes('965') && value.length >= 8) {
              phoneToUse = value;
              console.log('Found pre-filled phone number:', phoneToUse);
              break;
            }
          }
        }
        
        // More comprehensive phone field selectors for Shopify checkout
        const phoneSelectors = [
          'input[id="email"]', // This is the phone field with email ID
          'input[name="checkout[shipping_address][phone]"]',
          'input[name="checkout[billing_address][phone]"]',
          'input[type="tel"]',
          'input[placeholder*="phone" i]',
          'input[placeholder*="هاتف" i]',
          'input[placeholder*="رقم" i]',
          'input[data-testid*="phone"]',
          'input[aria-label*="phone" i]',
          'input[aria-label*="هاتف" i]',
          'input[data-testid="phone"]',
          'input[data-testid="shipping-phone"]',
          'input[data-testid="billing-phone"]',
          // Additional selectors for Shopify checkout
          'input[name="checkout[phone]"]',
          'input[name="checkout[shipping_address][phone_number]"]',
          'input[name="checkout[billing_address][phone_number]"]'
        ];
        
        let phoneFilled = false;
        for (const selector of phoneSelectors) {
          const element = document.querySelector(selector);
          if (element) {
            console.log('Found phone field with selector:', selector, 'Current value:', element.value);
            if (fillIf(selector, phoneToUse)) {
              console.log('Phone filled with selector:', selector, 'Value:', phoneToUse);
              phoneFilled = true;
              break;
            }
          }
        }
        
        // If still not filled, try to find any input that might be the phone field
        if (!phoneFilled) {
          console.log('Trying to find phone field by scanning all inputs...');
          const allInputs = document.querySelectorAll('input');
          for (const input of allInputs) {
            const id = input.id || '';
            const name = input.name || '';
            const placeholder = input.placeholder || '';
            const ariaLabel = input.getAttribute('aria-label') || '';
            
            // Check if this looks like a phone field
            if (id.includes('phone') || name.includes('phone') || 
                placeholder.toLowerCase().includes('phone') || 
                placeholder.includes('هاتف') || placeholder.includes('رقم') ||
                ariaLabel.toLowerCase().includes('phone') ||
                ariaLabel.includes('هاتف') || ariaLabel.includes('رقم')) {
              console.log('Found potential phone field:', {id, name, placeholder, ariaLabel});
              if (fillIf('#' + id, phoneToUse) || fillIf('[name="' + name + '"]', phoneToUse)) {
                console.log('Phone filled with fallback selector');
                phoneFilled = true;
                break;
              }
            }
          }
        }
        
        // Fill first name field
        const firstNameSelectors = [
          'input[name="checkout[shipping_address][first_name]"]',
          'input[name="checkout[billing_address][first_name]"]',
          'input[placeholder*="first" i]',
          'input[placeholder*="الاسم" i]',
          'input[data-testid*="first-name"]',
          'input[aria-label*="first" i]',
          // Additional selectors for Shopify checkout
          'input[name="checkout[first_name]"]',
          'input[data-testid="first-name"]',
          'input[data-testid="shipping-first-name"]',
          'input[data-testid="billing-first-name"]'
        ];
        
        let firstNameFilled = false;
        for (const selector of firstNameSelectors) {
          const element = document.querySelector(selector);
          if (element) {
            console.log('Found first name field with selector:', selector, 'Current value:', element.value);
            if (fillIf(selector, firstName)) {
              console.log('First name filled with selector:', selector);
              firstNameFilled = true;
              break;
            }
          }
        }
        
        // Fill last name field
        const lastNameSelectors = [
          'input[name="checkout[shipping_address][last_name]"]',
          'input[name="checkout[billing_address][last_name]"]',
          'input[placeholder*="last" i]',
          'input[placeholder*="اللقب" i]',
          'input[data-testid*="last-name"]',
          'input[aria-label*="last" i]',
          // Additional selectors for Shopify checkout
          'input[name="checkout[last_name]"]',
          'input[data-testid="last-name"]',
          'input[data-testid="shipping-last-name"]',
          'input[data-testid="billing-last-name"]'
        ];
        
        let lastNameFilled = false;
        for (const selector of lastNameSelectors) {
          const element = document.querySelector(selector);
          if (element) {
            console.log('Found last name field with selector:', selector, 'Current value:', element.value);
            if (fillIf(selector, lastName)) {
              console.log('Last name filled with selector:', selector);
              lastNameFilled = true;
              break;
            }
          }
        }
        
        // Fill address field
        const addressSelectors = [
          'input[name="checkout[shipping_address][address1]"]',
          'textarea[name="checkout[shipping_address][address1]"]',
          'input[placeholder*="address" i]',
          'input[placeholder*="عنوان" i]'
        ];
        
        let addressFilled = false;
        for (const selector of addressSelectors) {
          if (fillIf(selector, address1)) {
            console.log('Address filled with selector:', selector);
            addressFilled = true;
            break;
          }
        }
        
        // Fill city field
        const citySelectors = [
          'input[name="checkout[shipping_address][city]"]',
          'input[placeholder*="city" i]',
          'input[placeholder*="مدينة" i]'
        ];
        
        let cityFilled = false;
        for (const selector of citySelectors) {
          if (fillIf(selector, city)) {
            console.log('City filled with selector:', selector);
            cityFilled = true;
            break;
          }
        }
        
        // Fill province field
        const provinceSelectors = [
          'input[name="checkout[shipping_address][province]"]',
          'select[name="checkout[shipping_address][province]"]',
          'input[placeholder*="province" i]',
          'input[placeholder*="محافظة" i]'
        ];
        
        let provinceFilled = false;
        for (const selector of provinceSelectors) {
          if (selectIf(selector, province)) {
            console.log('Province filled with selector:', selector);
            provinceFilled = true;
            break;
          }
        }
        
        // Fill country field
        const countrySelectors = [
          'input[name="checkout[shipping_address][country]"]',
          'select[name="checkout[shipping_address][country]"]',
          'input[placeholder*="country" i]',
          'input[placeholder*="دولة" i]'
        ];
        
        let countryFilled = false;
        for (const selector of countrySelectors) {
          if (selectIf(selector, country)) {
            console.log('Country filled with selector:', selector);
            countryFilled = true;
            break;
          }
        }
        
        // Fill zip field
        const zipSelectors = [
          'input[name="checkout[shipping_address][zip]"]',
          'input[placeholder*="zip" i]',
          'input[placeholder*="postal" i]',
          'input[placeholder*="الرمز" i]'
        ];
        
        let zipFilled = false;
        for (const selector of zipSelectors) {
          if (fillIf(selector, zip)) {
            console.log('ZIP filled with selector:', selector);
            zipFilled = true;
            break;
          }
        }
        
        // Log filling results
        console.log('Form filling results:', {
          emailFilled, phoneFilled, firstNameFilled, lastNameFilled,
          addressFilled, cityFilled, provinceFilled, countryFilled, zipFilled
        });
        
        // Verify critical fields are filled
        if (!phoneFilled) {
          console.log('WARNING: Phone field was not filled!');
        }
        if (!emailFilled) {
          console.log('WARNING: Email field was not filled!');
        }
        
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
        
        // Step 4: Click continue/complete buttons with retry logic
        console.log('Looking for continue buttons...');
        const continueSelectors = [
          '#checkout-pay-button',
          'button#checkout-pay-button',
          'button[name="button"]',
          'button[type="submit"]',
          'button[data-continue-button]',
          'button.primary',
          'button[class*="continue"]',
          'button[class*="submit"]',
          'input[type="submit"]'
        ];
        
        let continueClicked = false;
        let retryCount = 0;
        const maxRetries = 3;
        
        while (!continueClicked && retryCount < maxRetries) {
          console.log(`Attempt ${retryCount + 1} to click continue button...`);
          
        for (const selector of continueSelectors) {
          if (clickIf(selector)) {
            console.log('Continue button clicked with selector:', selector);
            continueClicked = true;
            break;
          }
        }
        
          if (!continueClicked) {
            retryCount++;
            if (retryCount < maxRetries) {
              console.log(`Retrying in 2 seconds... (attempt ${retryCount + 1}/${maxRetries})`);
              await wait(2000);
            }
          }
        }
        
        if (continueClicked) {
          console.log('Continue button clicked successfully');
          await wait(3000);
        } else {
          console.log('Failed to click continue button after', maxRetries, 'attempts');
        }
        
        if (window.CheckoutListener && window.CheckoutListener.postMessage) {
          window.CheckoutListener.postMessage('step:5');
        }
        
        // Step 5: If still on checkout page, try alternative approaches
        if (window.location.href.includes('/checkouts/') && !window.location.href.includes('/thank_you')) {
          console.log('Still on checkout page, trying alternative approaches...');
          
          // Check for form validation errors first
          const errorElements = document.querySelectorAll('.error, .field-error, [class*="error"]');
          if (errorElements.length > 0) {
            console.log('Form validation errors detected:', errorElements.length);
            errorElements.forEach((el, index) => {
              console.log(`Error ${index + 1}:`, el.textContent || el.innerText);
            });
          }
          
          // Try clicking any visible buttons with text
          const allButtons = document.querySelectorAll('button, input[type="submit"], input[type="button"]');
          let buttonClicked = false;
          for (const btn of allButtons) {
            if (btn.offsetParent !== null && btn.textContent.trim()) {
              console.log('Trying button:', btn.textContent.trim());
              btn.click();
              await wait(2000);
              buttonClicked = true;
              break;
            }
          }
          
          if (!buttonClicked) {
            // Try form submission as last resort
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
        }
        
        console.log('Auto-confirm process completed');
      })();
    ''';

    try {
      await _controller.runJavaScriptReturningResult(script);
    } catch (e) {
      print('Auto-confirm script error: $e');
      _updateLoadingMessage('جاري معالجة الطلب...');
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
