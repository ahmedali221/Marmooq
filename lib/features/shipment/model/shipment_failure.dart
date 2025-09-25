/// Class representing possible failures in the shipment process
class ShipmentFailure {
  final String message;
  final ShipmentFailureType type;
  final dynamic originalError;

  const ShipmentFailure({
    required this.message,
    required this.type,
    this.originalError,
  });

  /// Create a failure for invalid address
  factory ShipmentFailure.invalidAddress(String message, {dynamic originalError}) {
    return ShipmentFailure(
      message: message,
      type: ShipmentFailureType.invalidAddress,
      originalError: originalError,
    );
  }

  /// Create a failure for unavailable shipping method
  factory ShipmentFailure.unavailableShippingMethod(String message, {dynamic originalError}) {
    return ShipmentFailure(
      message: message,
      type: ShipmentFailureType.unavailableShippingMethod,
      originalError: originalError,
    );
  }

  /// Create a failure for API errors
  factory ShipmentFailure.apiError(String message, {dynamic originalError}) {
    return ShipmentFailure(
      message: message,
      type: ShipmentFailureType.apiError,
      originalError: originalError,
    );
  }

  /// Create a failure for network errors
  factory ShipmentFailure.networkError(String message, {dynamic originalError}) {
    return ShipmentFailure(
      message: message,
      type: ShipmentFailureType.networkError,
      originalError: originalError,
    );
  }

  /// Create a failure for unexpected errors
  factory ShipmentFailure.unexpected(String message, {dynamic originalError}) {
    return ShipmentFailure(
      message: message,
      type: ShipmentFailureType.unexpected,
      originalError: originalError,
    );
  }

  @override
  String toString() => 'ShipmentFailure(type: $type, message: $message)';
}

/// Enum representing different types of shipment failures
enum ShipmentFailureType {
  invalidAddress,
  unavailableShippingMethod,
  apiError,
  networkError,
  unexpected,
}
