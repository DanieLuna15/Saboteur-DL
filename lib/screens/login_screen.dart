import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = AuthService();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Saboteur Online',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.amber),
            ),
            const SizedBox(height: 50),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: const Text('Iniciar con Google'),
              onPressed: () async {
                final result = await authService.signInWithGoogle();
                if (result == null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al iniciar con Google. Revisa la consola.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(250, 50),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () async {
                final result = await authService.signInAnonymously();
                if (result == null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error al entrar como invitado. ¿Habilitaste "Anónimo" en Firebase?')),
                  );
                }
              },
              child: const Text('Jugar como Invitado'),
            ),
          ],
        ),
      ),
    );
  }
}
