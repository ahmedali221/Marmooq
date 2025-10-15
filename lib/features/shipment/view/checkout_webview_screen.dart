import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:marmooq/features/shipment/models/checkout_models.dart';
import 'package:marmooq/features/cart/repository/cart_repository.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:io';

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

    // Set a stuck timer - on iOS be more aggressive (30 seconds)
    final stuckDuration = Platform.isIOS
        ? const Duration(seconds: 30)
        : const Duration(minutes: 1);

    _stuckTimer = Timer(stuckDuration, () {
      if (!_checkoutCompleted && mounted) {
        if (widget.silentMode) {
          // In silent mode on iOS, if stuck for 30 seconds, show the WebView
          print(
            '[iOS] Checkout appears stuck after ${stuckDuration.inSeconds}s, showing WebView',
          );
          setState(() {
            _showWebView = true;
          });
        } else {
          setState(() {
            _showWebView = true;
          });
          print(
            'Checkout appears stuck, showing WebView for manual completion',
          );
        }
      }
    });
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
    print('Platform: ${Platform.operatingSystem}');

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setUserAgent(
        Platform.isIOS
            ? 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1'
            : null,
      )
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
              // Try again after delays - more aggressive on iOS
              final retryDelays = Platform.isIOS
                  ? [3, 6, 10, 15] // iOS: retry every 3, 6, 10, 15 seconds
                  : [5, 10]; // Android: retry every 5, 10 seconds

              for (final delay in retryDelays) {
                Future.delayed(Duration(seconds: delay), () {
                  if (!_checkoutCompleted && mounted) {
                    print(
                      '[Retry] Attempting auto-confirm after ${delay}s delay',
                    );
                    _attemptAutoConfirm();
                  }
                });
              }
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('Web resource error: ${error.description}');
            print('Error type: ${error.errorType}');
            print('Error code: ${error.errorCode}');
            print('Platform: ${Platform.operatingSystem}');

            _handleNonCriticalError(error);
          },
        ),
      );

    print('Loading WebView with URL: ${widget.checkoutUrl}');
    _controller.loadRequest(Uri.parse(widget.checkoutUrl));
  }

  bool _isRunningAutoConfirm = false;

  // Attempt to auto-complete the checkout without showing UI.
  // This script tries common Shopify checkout flows:
  // - selects COD if present
  // - clicks primary action buttons across steps
  // - waits between actions to allow navigation
  Future<void> _attemptAutoConfirm() async {
    if (_checkoutCompleted || _isRunningAutoConfirm) return;
    _isRunningAutoConfirm = true;

    print(
      '[AutoConfirm] Starting auto-confirm process (attempt #${_startedAutoFlow ? 'retry' : '1'})',
    );
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
        
        // Step 1: Fill shipping information fields
        console.log('Filling shipping information...');
        
        // Extract URL parameters for form data
        const urlParams = new URLSearchParams(window.location.search);
        console.log('URL Parameters:', Object.fromEntries(urlParams.entries()));
        
        // Get phone number from URL parameters or use demo fallback
        let phoneNumber = urlParams.get('checkout[shipping_address][phone]') || 
                         urlParams.get('checkout[phone]') || 
                         '+96555544789'; // Demo phone fallback
        
        console.log('Using phone number:', phoneNumber);
        
        // Function to find phone field
        function findPhoneField() {
          // Strategy 1: Find label containing "رقم الهاتف" and get its associated input
          const labels = document.querySelectorAll('label');
          for (const label of labels) {
            if (label.textContent.includes('رقم الهاتف')) {
              console.log('Found label with "رقم الهاتف":', label.textContent);
              // Try to find the associated input
              const forId = label.getAttribute('for');
              if (forId) {
                const field = document.getElementById(forId);
                if (field) {
                  console.log('Found input by label for:', field);
                  return field;
                }
              } else {
                // Try to find input as sibling or child
                const field = label.querySelector('input') || label.nextElementSibling;
                if (field && field.tagName === 'INPUT') {
                  console.log('Found input as sibling/child:', field);
                  return field;
                }
              }
            }
          }
          
          // Strategy 2: Try specific selectors
          const phoneSelectors = [
            'input[id="email"]',
            'input[name="email"]',
            'input[placeholder*="رقم" i]',
            'input[placeholder*="هاتف" i]',
            'input[aria-label*="رقم الهاتف" i]'
          ];
          
          for (const selector of phoneSelectors) {
            const field = document.querySelector(selector);
            if (field) {
              console.log('Found phone field with selector:', selector);
              return field;
            }
          }
          
          return null;
        }
        
        // Wait for form fields to load with retry mechanism
        let phoneField = null;
        let retryCount = 0;
        const maxRetries = 10;
        
        while (!phoneField && retryCount < maxRetries) {
          console.log(`Attempt ${retryCount + 1}/${maxRetries} to find phone field...`);
          phoneField = findPhoneField();
          
          if (!phoneField) {
            console.log('Phone field not found, waiting 1 second before retry...');
            await wait(1000);
            retryCount++;
          }
        }
        
        let phoneFilled = false;
        if (phoneField) {
          console.log('Found phone field! Current value:', phoneField.value);
          console.log('Phone field details:', {
            id: phoneField.id,
            name: phoneField.name,
            type: phoneField.type,
            placeholder: phoneField.placeholder,
            value: phoneField.value
          });
          
          // Clear the field first to remove any existing email value
          phoneField.value = '';
          phoneField.dispatchEvent(new Event('input', {bubbles: true}));
          phoneField.dispatchEvent(new Event('change', {bubbles: true}));
          phoneField.dispatchEvent(new Event('blur', {bubbles: true}));
          
          // Wait a bit for the field to clear
          await wait(500);
          
          // Fill with phone number
          phoneField.value = phoneNumber;
          phoneField.dispatchEvent(new Event('input', {bubbles: true}));
          phoneField.dispatchEvent(new Event('change', {bubbles: true}));
          phoneField.dispatchEvent(new Event('blur', {bubbles: true}));
          phoneField.dispatchEvent(new Event('focus', {bubbles: true}));
          
          console.log('Phone field filled with value:', phoneNumber);
          console.log('Phone field value after filling:', phoneField.value);
          phoneFilled = true;
        }
        
        if (!phoneFilled) {
          console.log('WARNING: Could not find phone field to fill');
          // Debug: Show all input fields to help identify the correct selector
          const allInputs = document.querySelectorAll('input');
          console.log('All input fields on page:', allInputs.length);
          allInputs.forEach((input, index) => {
            console.log(`Input ${index + 1}:`, {
              id: input.id,
              name: input.name,
              type: input.type,
              placeholder: input.placeholder,
              value: input.value,
              className: input.className,
              'data-testid': input.getAttribute('data-testid'),
              'aria-label': input.getAttribute('aria-label')
            });
          });
          
          // Also check for any elements with id="email"
          const emailElements = document.querySelectorAll('[id="email"]');
          console.log('Elements with id="email":', emailElements.length);
          emailElements.forEach((el, index) => {
            console.log(`Email element ${index + 1}:`, {
              tagName: el.tagName,
              id: el.id,
              name: el.name,
              type: el.type,
              placeholder: el.placeholder,
              value: el.value
            });
          });
          
          // Try to fill any empty text input field as a last resort
          console.log('Trying to fill any empty input field as fallback...');
          const emptyInputs = document.querySelectorAll('input[type="text"]:not([readonly]):not([disabled]), input:not([type]):not([readonly]):not([disabled])');
          console.log('Found empty inputs:', emptyInputs.length);
          
          // Filter out inputs that already have values or are hidden
          const visibleEmptyInputs = Array.from(emptyInputs).filter(input => {
            const hasValue = input.value && input.value.trim() !== '';
            const isVisible = input.offsetParent !== null;
            const isNotRadioOrCheckbox = input.type !== 'radio' && input.type !== 'checkbox';
            console.log('Checking input:', {
              id: input.id,
              name: input.name,
              type: input.type,
              hasValue,
              isVisible,
              isNotRadioOrCheckbox,
              value: input.value
            });
            return !hasValue && isVisible && isNotRadioOrCheckbox;
          });
          
          console.log('Visible empty text inputs:', visibleEmptyInputs.length);
          if (visibleEmptyInputs.length > 0) {
            const firstEmptyInput = visibleEmptyInputs[0];
            console.log('Found empty input field to fill:', {
              id: firstEmptyInput.id,
              name: firstEmptyInput.name,
              type: firstEmptyInput.type,
              placeholder: firstEmptyInput.placeholder
            });
            firstEmptyInput.value = phoneNumber;
            firstEmptyInput.dispatchEvent(new Event('input', {bubbles: true}));
            firstEmptyInput.dispatchEvent(new Event('change', {bubbles: true}));
            firstEmptyInput.dispatchEvent(new Event('blur', {bubbles: true}));
            console.log('Filled empty input field with phone number:', phoneNumber);
            phoneFilled = true;
          }
        }
        
        // Also fill the actual email field if it exists and is empty
        const emailField = document.querySelector('input[type="email"], input[placeholder*="بريد" i], input[name*="email"]:not([id="email"])');
        if (emailField && emailField.id !== 'email') { // Don't touch the phone field with id="email"
          if (!emailField.value || !emailField.value.includes('@')) {
            console.log('Filling email field...');
            // Get email from URL parameters
            const emailFromUrl = urlParams.get('checkout[email]') || 'customer@example.com';
            emailField.value = emailFromUrl;
            emailField.dispatchEvent(new Event('input', {bubbles: true}));
            emailField.dispatchEvent(new Event('change', {bubbles: true}));
            emailField.dispatchEvent(new Event('blur', {bubbles: true}));
            console.log('Email field filled with:', emailFromUrl);
          } else {
            console.log('Email field already contains valid email:', emailField.value);
          }
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
        
        // Step 4: Click continue/complete buttons with enhanced detection
        console.log('Looking for continue buttons...');
        
        // Try multiple button finding strategies
        let continueButton = null;
        
        // Strategy 1: Try the SPECIFIC button ID first (checkout-pay-button)
        continueButton = document.getElementById('checkout-pay-button');
        if (continueButton && !continueButton.disabled) {
          console.log('Found checkout-pay-button by ID');
        } else {
          // Also try with querySelector in case it needs the # prefix
          continueButton = document.querySelector('#checkout-pay-button');
          if (continueButton && !continueButton.disabled) {
            console.log('Found checkout-pay-button with querySelector');
          } else {
            continueButton = null; // Reset if not found or disabled
            console.log('checkout-pay-button not found or disabled, trying other selectors...');
            
            // Strategy 2: Common Shopify selectors
        const continueSelectors = [
              'button#checkout-pay-button', // Try again with button prefix
          'button[type="submit"]',
              '#continue_button',
              'button[name="button"]',
              'button[data-trekkie-id="submit_button"]',
              'button.button--full-width',
              'button[aria-label*="Continue" i]',
              'button[aria-label*="Pay" i]',
          'input[type="submit"]'
        ];
        
        for (const selector of continueSelectors) {
            continueButton = document.querySelector(selector);
            if (continueButton && !continueButton.disabled) {
              console.log('Found continue button with selector:', selector);
            break;
            }
          }
        }
        
        // Strategy 3: Find any submit button if the above failed
        if (!continueButton) {
          const allButtons = document.querySelectorAll('button, input[type="submit"]');
          for (const btn of allButtons) {
            if (btn.offsetParent !== null && !btn.disabled) {
              const text = btn.textContent.toLowerCase();
              const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
              if (text.includes('continue') || text.includes('pay') || 
                  text.includes('complete') || text.includes('submit') ||
                  ariaLabel.includes('continue') || ariaLabel.includes('pay') ||
                  btn.type === 'submit') {
                continueButton = btn;
                console.log('Found button by text/aria:', text || ariaLabel);
                break;
              }
            }
          }
        }
        
        // Strategy 4: Click the first visible submit button as last resort
        if (!continueButton) {
          const submitButtons = document.querySelectorAll('button[type="submit"], input[type="submit"]');
          for (const btn of submitButtons) {
            if (btn.offsetParent !== null && !btn.disabled) {
              continueButton = btn;
              console.log('Using first visible submit button as fallback');
              break;
            }
          }
        }
        
        let continueClicked = false;
        if (continueButton) {
          // Check if button is disabled - if so, wait and try again
          if (continueButton.disabled) {
            console.log('Button found but disabled, waiting for it to become enabled...');
            let waitAttempts = 0;
            while (continueButton.disabled && waitAttempts < 10) {
              await wait(500);
              waitAttempts++;
              console.log(`Waiting for button to enable (attempt ${waitAttempts}/10)...`);
            }
          }
          
          if (!continueButton.disabled) {
            console.log('Clicking continue button:', continueButton.id || continueButton.className);
            continueButton.click();
            continueClicked = true;
            await wait(3000);
          } else {
            console.log('WARNING: Button is still disabled after waiting');
          }
        } else {
          console.log('WARNING: No continue button found');
          // Debug: List all buttons
          const allButtons = document.querySelectorAll('button');
          console.log('All buttons on page:', allButtons.length);
          allButtons.forEach((btn, i) => {
            console.log(`Button ${i + 1}:`, {
              text: btn.textContent.trim().substring(0, 50),
              type: btn.type,
              disabled: btn.disabled,
              className: btn.className,
              id: btn.id,
              visible: btn.offsetParent !== null
            });
          });
        }
        
        if (window.CheckoutListener && window.CheckoutListener.postMessage) {
          window.CheckoutListener.postMessage('step:5');
        }
        
        // Step 5: If still on checkout page, try alternative approaches
        if (window.location.href.includes('/checkouts/') && !window.location.href.includes('/thank_you')) {
          console.log('Still on checkout page, trying alternative approaches...');
          
          // Check for form validation errors first
          const errorElements = document.querySelectorAll('[class*="error"], [class*="invalid"], .field-error, .validation-error');
          if (errorElements.length > 0) {
            console.log('Form validation errors detected:', errorElements.length);
            
            // Check for Shopify server error
            let hasShopifyServerError = false;
            errorElements.forEach((el, index) => {
              const errorText = el.textContent.trim();
              console.log(`Error ${index + 1}:`, errorText);
              
              // Detect Shopify server error
              if (errorText.includes('There was a problem with our checkout') || 
                  errorText.includes('Refresh this page') ||
                  errorText.includes('try again in a few minutes')) {
                hasShopifyServerError = true;
                console.log('DETECTED: Shopify server error - will auto-refresh in 3 seconds');
              }
            });
            
            // If Shopify server error, refresh the page
            if (hasShopifyServerError) {
              console.log('Auto-refreshing page due to Shopify server error...');
              await wait(3000);
              window.location.reload();
              return; // Exit the function after reload
            }
            
            // Try to clear any error states (for regular validation errors)
            errorElements.forEach(el => {
              el.classList.remove('error', 'invalid', 'field-error', 'validation-error');
            });
            
            // Wait a bit for errors to clear
            await wait(1000);
          }
          
          // Try to fill any missing required fields
          const requiredFields = document.querySelectorAll('input[required], select[required], textarea[required]');
          requiredFields.forEach(field => {
            if (!field.value.trim()) {
              console.log('Filling required field:', field.name || field.id);
              if (field.type === 'text' || field.type === 'tel' || field.type === 'email') {
                // Special handling for phone field with id="email"
                if (field.id === 'email' || field.name.includes('phone') || field.placeholder.includes('رقم')) {
                  field.value = phoneNumber;
                  console.log('Filled phone field (id=email) with:', phoneNumber);
                } else if (field.name.includes('email') || field.placeholder.includes('بريد') || field.type === 'email') {
                  const emailFromUrl = urlParams.get('checkout[email]') || 'customer@example.com';
                  field.value = emailFromUrl;
                  console.log('Filled email field with:', emailFromUrl);
                } else {
                  field.value = 'Default Value';
                }
                field.dispatchEvent(new Event('input', {bubbles: true}));
                field.dispatchEvent(new Event('change', {bubbles: true}));
              }
            }
          });
          
          await wait(1000);
          
          // Try clicking any visible buttons with text
          const allButtons = document.querySelectorAll('button, input[type="submit"], input[type="button"]');
          for (const btn of allButtons) {
            if (btn.offsetParent !== null && btn.textContent.trim() && !btn.disabled) {
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
      print('[AutoConfirm] Script completed successfully');
    } catch (e) {
      print('[AutoConfirm] Script error: $e');
      _updateLoadingMessage('جاري معالجة الطلب...');
    } finally {
      // Reset the flag so we can retry if needed
      await Future.delayed(const Duration(seconds: 2));
      _isRunningAutoConfirm = false;
      print('[AutoConfirm] Auto-confirm process ended, ready for retry');
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
