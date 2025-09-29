import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:marmooq/features/auth/bloc/auth_bloc.dart';
import 'package:marmooq/features/auth/bloc/auth_state.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Create fade-in animation
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeInOut),
      ),
    );

    // Create scale animation
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // Start animation and initialize/authenticate immediately
    _animationController.forward();
    _checkAuthenticationStatus();
  }

  void _checkAuthenticationStatus() {
    // Check if widget is still mounted before accessing context
    if (mounted) {
      // Initialize authentication state
      context.read<AuthBloc>().add(AuthInitialize());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600;

    return Scaffold(
      backgroundColor: const Color(
        0xFFF6FBFC,
      ), // Match launch screen background
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (!mounted) return;

          if (state.isAuthenticated) {
            // Navigate to products if authenticated
            context.go('/products');
          } else if (state.status == AuthStatus.unauthenticated) {
            // Allow unauthenticated users to browse products
            context.go('/products');
          }
        },
        child: Container(
          decoration: const BoxDecoration(color: Color(0xFFF6FBFC)),
          child: Center(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeInAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo container with background circle
                        Container(
                          width: isTablet ? 160 : 120,
                          height: isTablet ? 160 : 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Image.asset(
                              'assets/marmooq_logo.png',
                              width: isTablet ? 100 : 80,
                              height: isTablet ? 100 : 80,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(height: isTablet ? 40 : 30),
                        Text(
                          'مرموق',
                          style: TextStyle(
                            fontSize: isTablet ? 48 : 36,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF00695C),
                            letterSpacing: 1.2,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'للتسوق الإلكتروني',
                          style: TextStyle(
                            fontSize: isTablet ? 20 : 16,
                            color: Colors.grey[600],
                            letterSpacing: 0.5,
                            fontFamily: 'Tajawal',
                          ),
                        ),
                        SizedBox(height: isTablet ? 80 : 60),
                        SizedBox(
                          width: isTablet ? 50 : 40,
                          height: isTablet ? 50 : 40,
                          child: CircularProgressIndicator.adaptive(
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF00695C),
                            ),
                            strokeWidth: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
