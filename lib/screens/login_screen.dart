import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = AuthService();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Title with Glow
                  ShaderMask(
                    shaderCallback: (bounds) => AppColors.goldGradient.createShader(bounds),
                    child: const Text(
                      'Saboteur',
                      style: TextStyle(
                        fontSize: 60,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const Text(
                    'ONLINE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.brightGold,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 60),
                  
                  // Google Sign In Button with Glow
                  Container(
                    width: 280,
                    decoration: AppTheme.goldGlowDecoration,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login, color: Colors.black),
                      label: const Text('INICIAR CON GOOGLE'),
                      onPressed: () async {
                        final result = await authService.signInWithGoogle();
                        if (result == null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Error al iniciar con Google.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Anonymous Login
                  TextButton(
                    onPressed: () async {
                      final result = await authService.signInAnonymously();
                      if (result == null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Error al entrar como invitado.')),
                        );
                      }
                    },
                    child: const Text(
                      'Jugar como Invitado',
                      style: TextStyle(
                        color: AppColors.cream,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
