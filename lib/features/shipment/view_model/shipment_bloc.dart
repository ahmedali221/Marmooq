// import 'package:bloc/bloc.dart';

// import 'package:traincode/features/shipment/repository/shipment_repository.dart';
// import 'package:traincode/features/shipment/view_model/shipment_events.dart';
// import 'package:traincode/features/shipment/view_model/shipment_states.dart';

// class ShippingBloc extends Bloc<ShippingEvent, ShippingState> {
//   final ShipmentRepository _repository;

//   ShippingBloc(this._repository) : super(ShippingInitial()) {
//     on<SubmitShippingAddress>(_onSubmitShippingAddress);
//   }

//   // Helper function to convert country codes to full country names
//   String _getCountryName(String countryCode) {
//     switch (countryCode.toUpperCase()) {
//       case 'KW':
//         return 'Kuwait';
//       case 'SA':
//         return 'Saudi Arabia';
//       case 'AE':
//         return 'United Arab Emirates';
//       case 'US':
//         return 'United States';
//       case 'CA':
//         return 'Canada';
//       case 'GB':
//         return 'United Kingdom';
//       case 'AU':
//         return 'Australia';
//       case 'DE':
//         return 'Germany';
//       case 'FR':
//         return 'France';
//       case 'ES':
//         return 'Spain';
//       case 'IT':
//         return 'Italy';
//       case 'JP':
//         return 'Japan';
//       case 'CN':
//         return 'China';
//       case 'IN':
//         return 'India';
//       case 'BR':
//         return 'Brazil';
//       case 'MX':
//         return 'Mexico';
//       default:
//         return countryCode; // Fallback to country code if not mapped
//     }
//   }

//   Future<void> _onSubmitShippingAddress(
//     SubmitShippingAddress event,
//     Emitter<ShippingState> emit,
//   ) async {
//     emit(ShippingLoading());
//     try {
//       // Validate inputs
//       if (event.customerAccessToken.isEmpty || event.cartId.isEmpty) {
//         throw Exception('Invalid customer access token or cart ID');
//       }
//       if (event.lineItems.isEmpty) {
//         throw Exception('Cart cannot be empty');
//       }

//       // Convert country code to full country name
//       final countryName = _getCountryName(event.country);

//       // Save address to customer account
//       await _repository.createCustomerAddress(
//         customerAccessToken: event.customerAccessToken,
//         address1: event.address1,
//         address2: event.address2,
//         city: event.city,
//         country: countryName, // Use full country name
//         province: event.province,
//         zip: event.zip,
//         firstName: event.firstName,
//         lastName: event.lastName,
//         phone: event.phone,
//         company: event.company,
//       );

//       // Update cart with shipping address
//       await _repository.updateCartBuyerIdentity(
//         cartId: event.cartId,
//         email: event.email,
//         countryCode: event.country, // Keep country code for this method
//         address1: event.address1,
//         address2: event.address2,
//         city: event.city,
//         province: event.province,
//         zip: event.zip,
//         firstName: event.firstName,
//         lastName: event.lastName,
//         phone: event.phone,
//         company: event.company,
//       );

//       // Create checkout
//       final checkout = await _repository.createCheckout(
//         email: event.email,
//         address1: event.address1,
//         address2: event.address2,
//         city: event.city,
//         country: countryName, // Use full country name
//         province: event.province,
//         zip: event.zip,
//         firstName: event.firstName,
//         lastName: event.lastName,
//         phone: event.phone,
//         company: event.company,
//         lineItems: event.lineItems,
//       );

//       emit(
//         CheckoutCreated(
//           checkoutId: checkout['id'] as String,
//           webUrl: checkout['webUrl'] as String,
//           availableShippingRates: List<Map<String, dynamic>>.from(
//             checkout['availableShippingRates']?['shippingRates'] ?? [],
//           ),
//         ),
//       );
//     } catch (e) {
//       emit(ShippingError('Error: ${e.toString()}'));
//     }
//   }
// }
