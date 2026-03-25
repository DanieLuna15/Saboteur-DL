import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  double _loadingProgress = 0.0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startLoading();
  }

  void _startLoading() {
    const duration = Duration(milliseconds: 50);
    _timer = Timer.periodic(duration, (timer) {
      setState(() {
        if (_loadingProgress < 1.0) {
          _loadingProgress += 0.02; // Simulate loading
        } else {
          _timer?.cancel();
          _navigateToHome();
        }
      });
    });
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const AuthWrapper()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Banner Image
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/banner.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Game Title
                const Text(
                  'SABOTEUR',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brightGold,
                    letterSpacing: 4,
                  ),
                ),
                const Text(
                  'EL ORO TE ESPERA...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.cream,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 60),
                
                // Clash Royale Style Loading Bar
                SizedBox(
                  width: 250,
                  height: 30,
                  child: Stack(
                    children: [
                      // Outer Border
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.sabotageDark,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: AppColors.brownPrimary, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(0, 4),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      // Progress Fill
                      FractionallySizedBox(
                        widthFactor: _loadingProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primaryGold, AppColors.orangeAccent],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.brightGold.withOpacity(0.3),
                                blurRadius: 5,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ... (rest of the Stack items kept as is)
                      // Shine Overlay
                      FractionallySizedBox(
                        widthFactor: _loadingProgress,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      // Percentage Text
                      Center(
                        child: Text(
                          '${(_loadingProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 2, offset: Offset(1, 1)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Cargando recursos...',
                  style: TextStyle(color: AppColors.cream, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
