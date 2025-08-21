import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:traincode/features/products/model/products_repository.dart';
import 'package:traincode/features/products/view/products_view.dart';
import 'package:traincode/features/products/view_model/products_bloc.dart';
import 'package:traincode/splash_screen.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shopify_flutter/shopify_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(); // uses .env by default

  ShopifyConfig.setConfig(
    storefrontAccessToken: dotenv.env['SHOPIFY_STOREFRONT_TOKEN']!,
    storeUrl: 'fagk1b-a1.myshopify.com',
    storefrontApiVersion: '2024-07',
    language: 'ar',
  );

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final GoRouter router = GoRouter(
      initialLocation: '/products', // Changed to products as initial view
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SplashScreen()),

        GoRoute(
          path: '/products',
          builder: (context, state) => const ProductsView(),
        ),
        // Add more routes for other features later
      ],
    );

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(create: (context) => ProductsRepository()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) =>
                ProductsBloc(context.read<ProductsRepository>()),
          ),
        ],
        child: MaterialApp.router(
          title: 'متجر مستحضرات التجميل', // Cosmetic Store in Arabic
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
            useMaterial3: true,
            fontFamily: 'Arial',
            // Force RTL text direction
            visualDensity: VisualDensity.adaptivePlatformDensity,
          ),
          // Remove localization delegates - Arabic only
          locale: const Locale('ar', 'KW'),
          // Force RTL layout direction
          builder: (context, child) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            );
          },
          routerConfig: router,
        ),
      ),
    );
  }
}
