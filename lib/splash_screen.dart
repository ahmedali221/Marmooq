import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:traincode/main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _firstAnimationController;
  late AnimationController _secondAnimationController;
  bool _showFirstAnimation = true;

  @override
  void initState() {
    super.initState();

    // Initialize animation controllers
    _firstAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _secondAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Start the first animation
    _startFirstAnimation();
  }

  void _startFirstAnimation() {
    _firstAnimationController.forward().then((_) {
      // After first animation completes, switch to second animation
      setState(() {
        _showFirstAnimation = false;
      });
      _startSecondAnimation();
    });
  }

  void _startSecondAnimation() {
    _secondAnimationController.forward().then((_) {
      // After second animation completes, navigate to main screen
      context.go('/login');
    });
  }

  @override
  void dispose() {
    _firstAnimationController.dispose();
    _secondAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _showFirstAnimation
            ? Lottie.asset(
                'assets/Splash1.json',
                controller: _firstAnimationController,
                onLoaded: (composition) {
                  _firstAnimationController.duration = composition.duration;
                },
              )
            : Lottie.asset(
                'assets/Splash2.json',
                controller: _secondAnimationController,
                onLoaded: (composition) {
                  _secondAnimationController.duration = composition.duration;
                },
              ),
      ),
    );
  }
}
