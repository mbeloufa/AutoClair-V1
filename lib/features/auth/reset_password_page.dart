import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/auth_layout.dart';
import 'auth_service.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});
  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _service = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _error = null; });
    try {
      await _service.updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre mot de passe a été modifié.')),
      );
      context.go('/home');
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Créer un nouveau mot de passe',
      subtitle: 'Utilisez le lien de récupération reçu par e-mail.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _password,
              obscureText: true,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Nouveau mot de passe',
                prefixIcon: Icon(Icons.lock_reset_outlined),
              ),
              validator: (value) => (value?.length ?? 0) < 12
                  ? '12 caractères minimum' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirmez le nouveau mot de passe',
              ),
              validator: (value) => value != _password.text
                  ? 'Les mots de passe sont différents' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              )),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: Text(_busy ? 'Enregistrement…' : 'Valider le mot de passe'),
            ),
            TextButton(
              onPressed: () => context.go('/forgot-password'),
              child: const Text('Demander un nouveau lien'),
            ),
          ],
        ),
      ),
    );
  }
}
