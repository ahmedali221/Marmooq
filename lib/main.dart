import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shopify_flutter/shopify_flutter.dart';
import 'package:traincode/features/auth/bloc/auth_bloc.dart';
import 'package:traincode/features/auth/screens/forgot_password_screen.dart';
import 'package:traincode/features/auth/screens/login_screen.dart';
import 'package:traincode/features/auth/screens/register_screen.dart';
import 'package:traincode/features/cart/repository/cart_repository.dart';
import 'package:traincode/features/cart/view/cart_screen.dart';
import 'package:traincode/features/cart/view_model/cart_bloc.dart';
import 'package:traincode/features/cart/view_model/cart_events.dart';
import 'package:traincode/features/products/model/products_repository.dart';
import 'package:traincode/features/products/view/products_view.dart';
import 'package:traincode/features/products/view_model/products_bloc.dart';
import 'package:traincode/features/shipment/repository/shipment_repository.dart';
import 'package:traincode/features/shipment/view/orderConfirmationPage.dart';
import 'package:traincode/features/shipment/view/shipmentPage.dart';
import 'package:traincode/features/shipment/view_model/shipment_bloc.dart';

import 'package:traincode/splash_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(); // uses .env by default

  ShopifyConfig.setConfig(
    storefrontAccessToken: dotenv.env['SHOPIFY_STOREFRONT_TOKEN']!,
    storeUrl: 'fagk1b-a1.myshopify.com',
    storefrontApiVersion: '2024-07',
    language: 'ar',
  );
  final shopifyLocalization = ShopifyLocalization.instance;
  shopifyLocalization.setCountryCode('KW');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final cartRepository = CartRepository();
    final shipmentRepository = ShipmentRepository();

    final GoRouter router = GoRouter(
      initialLocation: '/login',
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsView(),
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
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
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
          BlocProvider(
            create: (context) =>
                ShippingBloc(context.read<ShipmentRepository>()),
          ),
        ],
        child: MaterialApp.router(
          title: 'TrainCode',
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
