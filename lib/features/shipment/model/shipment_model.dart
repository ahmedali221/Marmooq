import 'package:equatable/equatable.dart';
import 'package:marmooq/features/shipment/model/address_model.dart';
import 'package:marmooq/features/shipment/model/shipping_method_model.dart';

/// Model class representing a complete shipment with address and selected shipping method
class ShipmentModel extends Equatable {
  final String? id;
  final AddressModel? shippingAddress;
  final AddressModel? billingAddress;
  final ShippingMethodModel? selectedShippingMethod;
  final bool useSameAddressForBilling;
  final String? specialInstructions;
  final bool isComplete;

  const ShipmentModel({
    this.id,
    this.shippingAddress,
    this.billingAddress,
    this.selectedShippingMethod,
    this.useSameAddressForBilling = true,
    this.specialInstructions,
    this.isComplete = false,
  });

  /// Creates a copy of this ShipmentModel with the given fields replaced with new values
  ShipmentModel copyWith({
    String? id,
    AddressModel? shippingAddress,
    AddressModel? billingAddress,
    ShippingMethodModel? selectedShippingMethod,
    bool? useSameAddressForBilling,
    String? specialInstructions,
    bool? isComplete,
  }) {
    return ShipmentModel(
      id: id ?? this.id,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      billingAddress: billingAddress ?? this.billingAddress,
      selectedShippingMethod: selectedShippingMethod ?? this.selectedShippingMethod,
      useSameAddressForBilling: useSameAddressForBilling ?? this.useSameAddressForBilling,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  /// Create from map (for persistence)
  factory ShipmentModel.fromMap(Map<String, dynamic> map) {
    return ShipmentModel(
      id: map['id'],
      shippingAddress: map['shippingAddress'] != null
          ? AddressModel.fromMap(map['shippingAddress'])
          : null,
      billingAddress: map['billingAddress'] != null
          ? AddressModel.fromMap(map['billingAddress'])
          : null,
      selectedShippingMethod: map['selectedShippingMethod'] != null
          ? ShippingMethodModel.fromMap(map['selectedShippingMethod'])
          : null,
      useSameAddressForBilling: map['useSameAddressForBilling'] ?? true,
      specialInstructions: map['specialInstructions'],
      isComplete: map['isComplete'] ?? false,
    );
  }

  /// Convert to map (for persistence)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'shippingAddress': shippingAddress?.toMap(),
      'billingAddress': billingAddress?.toMap(),
      'selectedShippingMethod': selectedShippingMethod?.toMap(),
      'useSameAddressForBilling': useSameAddressForBilling,
      'specialInstructions': specialInstructions,
      'isComplete': isComplete,
    };
  }

  /// Check if shipment is ready for checkout
  bool get isReadyForCheckout {
    final hasValidShippingAddress = shippingAddress?.isComplete ?? false;
    final hasValidBillingAddress = useSameAddressForBilling
        ? true
        : billingAddress?.isComplete ?? false;
    final hasShippingMethod = selectedShippingMethod != null;

    return hasValidShippingAddress && hasValidBillingAddress && hasShippingMethod;
  }

  /// Get effective billing address (either dedicated billing address or shipping address if same)
  AddressModel? get effectiveBillingAddress {
    return useSameAddressForBilling ? shippingAddress : billingAddress;
  }

  @override
  List<Object?> get props => [
        id,
        shippingAddress,
        billingAddress,
        selectedShippingMethod,
        useSameAddressForBilling,
        specialInstructions,
        isComplete,
      ];
}
