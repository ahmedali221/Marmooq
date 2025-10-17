import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:marmooq/features/auth/bloc/auth_bloc.dart';
import 'package:marmooq/features/auth/screens/login_screen.dart';
import 'package:marmooq/features/auth/screens/register_screen.dart';
import 'package:marmooq/features/auth/screens/profile_screen.dart';
// import 'package:marmooq/features/auth/screens/edit_profile_screen.dart';
// import 'package:marmooq/features/auth/screens/addresses_screen.dart';
import 'package:marmooq/features/cart/repository/cart_repository.dart';
import 'package:marmooq/features/cart/view/cart_screen.dart';
import 'package:marmooq/features/cart/view_model/cart_bloc.dart';
import 'package:marmooq/features/cart/view_model/cart_events.dart';
import 'package:marmooq/features/products/model/products_repository.dart';
import 'package:marmooq/core/navigation/main_navigation.dart';
import 'package:marmooq/features/products/view_model/products_bloc.dart';
import 'package:marmooq/features/shipment/repository/shipment_repository.dart';
import 'package:marmooq/features/shipment/view/orderConfirmationPage.dart';
import 'package:marmooq/features/shipment/view/shipmentPage.dart';
import 'package:marmooq/features/products/view/collection_details_view.dart';
import 'package:marmooq/features/products/view/product_details_view.dart';
import 'package:marmooq/features/products/model/product_model.dart' as local;
// import 'package:marmooq/features/shipment/view_model/shipment_bloc.dart';

import 'package:marmooq/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(); // uses .env by default

  // Request App Tracking Transparency authorization on iOS before any tracking.
  await _requestTrackingAuthorizationIfNeeded();

  ShopifyConfig.setConfig(
    storefrontAccessToken: dotenv.env['SHOPIFY_STOREFRONT_TOKEN']!,
    adminAccessToken: dotenv.env['ADMIN_ACCESS_TOKEN']!,
    storeUrl: 'fagk1b-a1.myshopify.com',
    storefrontApiVersion: '2025-07',
    language: 'ar',
  );
  final shopifyLocalization = ShopifyLocalization.instance;
  shopifyLocalization.setCountryCode('KW');

  // Enable performance optimizations
  if (kDebugMode) {
    debugProfileBuildsEnabled = true;
  }

  runApp(const MyApp());
}

Future<void> _requestTrackingAuthorizationIfNeeded() async {
  if (!Platform.isIOS) return;
  try {
    final TrackingStatus currentStatus =
        await AppTrackingTransparency.trackingAuthorizationStatus;
    if (currentStatus == TrackingStatus.notDetermined) {
      await AppTrackingTransparency.requestTrackingAuthorization();
    }

    // Optionally fetch IDFA only after authorization is granted.
    final TrackingStatus updatedStatus =
        await AppTrackingTransparency.trackingAuthorizationStatus;
    if (updatedStatus == TrackingStatus.authorized) {
      // Initialize any analytics/ads SDKs here in the future if added.
      // Example: await _initializeTrackingSdks();
    }
  } catch (_) {
    // Silently ignore errors to avoid startup crashes.
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const String initialRouteOverride = String.fromEnvironment(
      'APP_INITIAL_ROUTE',
      defaultValue: '/',
    );
    final cartRepository = CartRepository();
    final shipmentRepository = ShipmentRepository();

    final GoRouter router = GoRouter(
      initialLocation: initialRouteOverride,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/products',
          builder: (context, state) => const MainNavigation(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),

        // GoRoute(
        //   path: '/edit-profile',
        //   builder: (context, state) => const EditProfileScreen(),
        // ),
        // GoRoute(
        //   path: '/addresses',
        //   builder: (context, state) => const AddressesScreen(),
        // ),
        GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
        GoRoute(
          path: '/collection',
          builder: (context, state) {
            final Map<String, dynamic> extra =
                state.extra as Map<String, dynamic>;
            return CollectionDetailsView(
              collectionName: extra['collectionName'] as String,
              products: extra['products'] as List<local.Product>,
            );
          },
        ),
        GoRoute(
          path: '/product-details',
          name: 'product-details',
          builder: (context, state) {
            final local.Product product = state.extra as local.Product;
            return ProductDetailsView(product: product);
          },
        ),
        GoRoute(
          path: '/shipment',
          builder: (context, state) {
            final Map<String, dynamic> extra =
                state.extra as Map<String, dynamic>;
            return ShippingDetailsScreen(
              customerAccessToken: extra['customerAccessToken'] as String,
              cartId: extra['cartId'] as String,
              email: extra['email'] as String,
            );
          },
        ),
        GoRoute(
          path: '/order-confirmation',
          builder: (context, state) {
            final Map<String, dynamic> extra =
                state.extra as Map<String, dynamic>;
            return OrderConfirmationScreen(
              message: extra['message'] as String,
              checkoutId: extra['checkoutId'] as String?,
            );
          },
        ),
      ],
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => ProductsRepository()),
        RepositoryProvider(create: (context) => cartRepository),
        RepositoryProvider(create: (context) => shipmentRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                ProductsBloc(context.read<ProductsRepository>()),
          ),
          BlocProvider(create: (context) => AuthBloc()),
          BlocProvider(
            create: (context) {
              final cartBloc = CartBloc(cartRepository: cartRepository);
              cartBloc.add(LoadCartEvent());
              return cartBloc;
            },
          ),
          // BlocProvider(
          //   create: (context) =>
          //       ShippingBloc(context.read<ShipmentRepository>()),
          // ),
        ],
        child: MaterialApp.router(
          title: 'marmooq',
          theme: ThemeData(
            primarySwatch:
                Colors.teal, // Updated to match ShippingDetailsScreen
            visualDensity: VisualDensity.adaptivePlatformDensity,
            textTheme: const TextTheme(
              bodyMedium: TextStyle(
                fontFamily: 'Tajawal',
              ), // Arabic-friendly font
            ),
          ),
          routerConfig: router,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
