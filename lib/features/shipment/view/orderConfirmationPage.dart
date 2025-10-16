import 'dart:async';
import 'package:flutter/material.dart';
import 'package:feather_icons/feather_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/core/constants/app_colors.dart';
import 'package:marmooq/core/utils/responsive_utils.dart';

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
  bool _isVerifying = true;
  bool _isOrderCompleted = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _verifyOrderCompletion();
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

  Future<void> _verifyOrderCompletion() async {
    if (widget.checkoutId == null) {
      setState(() {
        _isVerifying = false;
        _isOrderCompleted = true; // Assume success if no ID
      });
      if (widget.autoRedirect) {
        _startAutoRedirect();
      }
      return;
    }

    // For COD checkout, we assume the order is completed since we got here
    // The checkout was already processed in the previous step
    setState(() {
      _isVerifying = false;
      _isOrderCompleted = true;
    });

    if (_isOrderCompleted && widget.autoRedirect) {
      _startAutoRedirect();
    }
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
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: _isVerifying
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'جاري التحقق من حالة الطلب...',
                      style: TextStyle(fontSize: 16, fontFamily: 'Tajawal'),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                )
              : _isOrderCompleted
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FeatherIcons.checkCircle,
                      color: AppColors.brand,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 80,
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 16,
                      ),
                    ),
                    Text(
                      'تم تقديم طلبك بنجاح!',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 20,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontFamily: 'Tajawal',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 10,
                      ),
                    ),
                    Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 16,
                        ),
                        color: Colors.grey,
                        fontFamily: 'Tajawal',
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                    if (widget.checkoutId != null) ...[
                      SizedBox(
                        height: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 10,
                        ),
                      ),
                      Container(
                        padding: ResponsiveUtils.getResponsivePadding(context),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveBorderRadius(
                              context,
                              mobile: 12,
                            ),
                          ),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FeatherIcons.fileText,
                                  color: Colors.grey[600],
                                  size: ResponsiveUtils.getResponsiveIconSize(
                                    context,
                                    mobile: 20,
                                  ),
                                ),
                                SizedBox(
                                  width: ResponsiveUtils.getResponsiveSpacing(
                                    context,
                                    mobile: 8,
                                  ),
                                ),
                                Text(
                                  'تفاصيل الطلب',
                                  style: TextStyle(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                          context,
                                          mobile: 16,
                                        ),
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                    fontFamily: 'Tajawal',
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                            SizedBox(
                              height: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                mobile: 12,
                              ),
                            ),
                            Text(
                              'رقم الطلب: ${widget.checkoutId}',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context,
                                  mobile: 14,
                                ),
                                color: Colors.grey,
                                fontFamily: 'Tajawal',
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                            if (widget.totalPrice != null) ...[
                              SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                  context,
                                  mobile: 8,
                                ),
                              ),
                              Text(
                                'إجمالي المبلغ: ${widget.totalPrice}',
                                style: TextStyle(
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                        context,
                                        mobile: 14,
                                      ),
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
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 20,
                      ),
                    ),
                    // Auto-redirect countdown
                    if (_isRedirecting) ...[
                      Container(
                        padding: ResponsiveUtils.getResponsivePadding(context),
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
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  FeatherIcons.clock,
                                  color: AppColors.brand,
                                  size: ResponsiveUtils.getResponsiveIconSize(
                                    context,
                                    mobile: 20,
                                  ),
                                ),
                                SizedBox(
                                  width: ResponsiveUtils.getResponsiveSpacing(
                                    context,
                                    mobile: 8,
                                  ),
                                ),
                                Text(
                                  'سيتم التوجيه تلقائياً خلال $_remainingSeconds ثانية',
                                  style: TextStyle(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                          context,
                                          mobile: 14,
                                        ),
                                    color: Colors.teal[700],
                                    fontFamily: 'Tajawal',
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                            SizedBox(
                              height: ResponsiveUtils.getResponsiveSpacing(
                                context,
                                mobile: 12,
                              ),
                            ),
                            TextButton(
                              onPressed: _cancelAutoRedirect,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.brand,
                              ),
                              child: const Text(
                                'إلغاء التوجيه التلقائي',
                                style: TextStyle(
                                  fontFamily: 'Tajawal',
                                  fontSize: 12,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: ResponsiveUtils.getResponsiveSpacing(
                          context,
                          mobile: 20,
                        ),
                      ),
                    ],
                    ElevatedButton(
                      onPressed: () => context.go('/products'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: Size.fromHeight(
                          ResponsiveUtils.getResponsiveHeight(
                            context,
                            mobile: 50,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveBorderRadius(
                              context,
                              mobile: 12,
                            ),
                          ),
                        ),
                      ),
                      child: Text(
                        _isRedirecting
                            ? 'العودة إلى التسوق الآن'
                            : 'العودة إلى التسوق',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                            context,
                            mobile: 16,
                          ),
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Tajawal',
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      FeatherIcons.alertCircle,
                      color: Colors.red,
                      size: ResponsiveUtils.getResponsiveIconSize(
                        context,
                        mobile: 80,
                      ),
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 16,
                      ),
                    ),
                    Text(
                      'خطأ في الطلب',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 20,
                        ),
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                        fontFamily: 'Tajawal',
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 10,
                      ),
                    ),
                    Text(
                      _errorMessage,
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getResponsiveFontSize(
                          context,
                          mobile: 16,
                        ),
                        color: Colors.grey,
                        fontFamily: 'Tajawal',
                      ),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(
                        context,
                        mobile: 20,
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => context.go('/shipment'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        minimumSize: Size.fromHeight(
                          ResponsiveUtils.getResponsiveHeight(
                            context,
                            mobile: 50,
                          ),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveBorderRadius(
                              context,
                              mobile: 12,
                            ),
                          ),
                        ),
                      ),
                      child: const Text(
                        'العودة إلى الشحن',
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
