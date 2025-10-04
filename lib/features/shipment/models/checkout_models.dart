class CheckoutResult {
  final bool success;
  final String? url;
  final String? checkoutId;
  final dynamic totalPrice;
  final bool? cancelled;
  final bool? timeout;
  final String? error;
  final bool? autoRedirect;

  const CheckoutResult({
    required this.success,
    this.url,
    this.checkoutId,
    this.totalPrice,
    this.cancelled,
    this.timeout,
    this.error,
    this.autoRedirect,
  });

  factory CheckoutResult.success({
    required String url,
    String? checkoutId,
    dynamic totalPrice,
    bool autoRedirect = false,
  }) {
    return CheckoutResult(
      success: true,
      url: url,
      checkoutId: checkoutId,
      totalPrice: totalPrice,
      autoRedirect: autoRedirect,
    );
  }

  factory CheckoutResult.cancelled() {
    return const CheckoutResult(success: false, cancelled: true);
  }

  factory CheckoutResult.timeout() {
    return const CheckoutResult(success: false, timeout: true);
  }

  factory CheckoutResult.error(String error) {
    return CheckoutResult(success: false, error: error);
  }
}

class CheckoutData {
  final String id;
  final String webUrl;
  final dynamic totalPrice;

  const CheckoutData({
    required this.id,
    required this.webUrl,
    required this.totalPrice,
  });

  factory CheckoutData.fromMap(Map<String, dynamic> map) {
    return CheckoutData(
      id: map['id'] as String,
      webUrl: map['webUrl'] as String,
      totalPrice: map['totalPrice'],
    );
  }
}
