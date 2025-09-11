import 'dart:async';
import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:traincode/core/constants/app_colors.dart';

class OrderConfirmationScreen extends StatefulWidget {
  final String message;
  final String? checkoutId;
  final String? webUrl;
  final String? totalPrice;
  final bool autoRedirect;
  final int redirectDelaySeconds;

  const OrderConfirmationScreen({
    super.key,
    required this.message,
    this.checkoutId,
    this.webUrl,
    this.totalPrice,
    this.autoRedirect = true,
    this.redirectDelaySeconds = 5,
  });

  static const String routeName = '/order-confirmation';

  // Factory constructor to create from route parameters
  static OrderConfirmationScreen fromRoute(Map<String, dynamic> extra) {
    return OrderConfirmationScreen(
      message: extra['message'] as String? ?? 'تم إتمام الطلب بنجاح!',
      checkoutId: extra['checkoutId'] as String?,
      webUrl: extra['webUrl'] as String?,
      totalPrice: extra['totalPrice'] as String?,
      autoRedirect: extra['autoRedirect'] as bool? ?? true,
      redirectDelaySeconds: extra['redirectDelaySeconds'] as int? ?? 5,
    );
  }

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  Timer? _redirectTimer;
  int _remainingSeconds = 0;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoRedirect) {
      _startAutoRedirect();
    }
  }

  @override
  void dispose() {
    _redirectTimer?.cancel();
    super.dispose();
  }

  void _startAutoRedirect() {
    setState(() {
      _remainingSeconds = widget.redirectDelaySeconds;
      _isRedirecting = true;
    });

    _redirectTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          context.go('/products');
        }
      } else {
        setState(() {
          _remainingSeconds--;
        });
      }
    });
  }

  void _cancelAutoRedirect() {
    _redirectTimer?.cancel();
    setState(() {
      _isRedirecting = false;
      _remainingSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'تأكيد الطلب',
          style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Tajawal'),
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(FeatherIcons.chevronLeft, color: Colors.white),
          onPressed: () => context.go('/products'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                FeatherIcons.checkCircle,
                color: AppColors.brand,
                size: 80,
              ),
              const SizedBox(height: 16),
              const Text(
                'تم تقديم طلبك بنجاح!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: 'Tajawal',
                ),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 10),
              Text(
                widget.message,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontFamily: 'Tajawal',
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
              ),
              if (widget.checkoutId != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            FeatherIcons.fileText,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'تفاصيل الطلب',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                              fontFamily: 'Tajawal',
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'رقم الطلب: ${widget.checkoutId}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontFamily: 'Tajawal',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      if (widget.totalPrice != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'إجمالي المبلغ: ${widget.totalPrice}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontFamily: 'Tajawal',
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              // Auto-redirect countdown
              if (_isRedirecting) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.brandLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.brandMuted, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            FeatherIcons.clock,
                            color: AppColors.brand,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'سيتم التوجيه تلقائياً خلال $_remainingSeconds ثانية',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.teal[700],
                              fontFamily: 'Tajawal',
                              fontWeight: FontWeight.w500,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _cancelAutoRedirect,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brand,
                        ),
                        child: const Text(
                          'إلغاء التوجيه التلقائي',
                          style: TextStyle(fontFamily: 'Tajawal', fontSize: 12),
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              ElevatedButton(
                onPressed: () => context.go('/products'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isRedirecting
                      ? 'العودة إلى التسوق الآن'
                      : 'العودة إلى التسوق',
                  style: const TextStyle(
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
