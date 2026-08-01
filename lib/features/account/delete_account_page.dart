import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import 'account_deletion_confirmation.dart';
import 'account_deletion_service.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phraseController = TextEditingController();
  final _service = AccountDeletionService();

  bool _understood = false;
  bool _deleting = false;

  String get _accountEmail =>
      Supabase.instance.client.auth.currentUser?.email?.trim() ?? '';

  @override
  void dispose() {
    _emailController.dispose();
    _phraseController.dispose();
    super.dispose();
  }

  Future<void> _deleteAccount() async {
    if (_deleting || !_formKey.currentState!.validate()) {
      return;
    }

    if (!_understood) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Confirmez que vous comprenez le caractère irréversible.',
          ),
        ),
      );
      return;
    }

    final finalConfirmation = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppColors.error,
            size: 48,
          ),
          title: const Text('Dernière confirmation'),
          content: const Text(
            'Le compte, les véhicules, les documents, les analyses '
            'et les fichiers privés seront définitivement supprimés.\n\n'
            'Aucune restauration ne sera possible.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Supprimer mon compte'),
            ),
          ],
        );
      },
    );

    if (finalConfirmation != true || !mounted) {
      return;
    }

    setState(() => _deleting = true);

    try {
      await _service.deleteCurrentAccount(
        email: _emailController.text,
        confirmation: _phraseController.text,
      );

      if (!mounted) {
        return;
      }

      context.go('/login');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(
          const SnackBar(
            content: Text('Votre compte et vos données ont été supprimés.'),
          ),
        );
      });
    } on AccountDeletionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _deleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountEmail = _accountEmail;

    return Scaffold(
      appBar: AppBar(title: const Text('Supprimer mon compte')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.28),
                ),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.error,
                    size: 54,
                  ),
                  SizedBox(height: 14),
                  Text(
                    'Cette action est définitive',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'La suppression ne pourra pas être annulée '
                    'et aucune sauvegarde utilisateur ne sera conservée.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Données supprimées',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const _DeletedDataRow(
              icon: Icons.person_outline,
              label: 'Compte et profil AutoClair',
            ),
            const _DeletedDataRow(
              icon: Icons.directions_car_outlined,
              label: 'Véhicules enregistrés',
            ),
            const _DeletedDataRow(
              icon: Icons.description_outlined,
              label: 'Documents et fichiers privés',
            ),
            const _DeletedDataRow(
              icon: Icons.auto_awesome_outlined,
              label: "Résultats d'analyse",
            ),
            const SizedBox(height: 26),
            Text(
              'Confirmation de sécurité',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Compte connecté : $accountEmail',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              enabled: !_deleting,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Confirmez votre adresse e-mail',
                prefixIcon: Icon(Icons.email_outlined),
              ),
              validator: (value) => AccountDeletionConfirmation.validateEmail(
                value: value,
                expectedEmail: accountEmail,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phraseController,
              enabled: !_deleting,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Phrase de confirmation',
                prefixIcon: Icon(Icons.edit_outlined),
                helperText:
                    'Respectez exactement les majuscules et les espaces.',
              ),
              validator: AccountDeletionConfirmation.validatePhrase,
            ),
            const SizedBox(height: 10),
            SelectableText(
              AccountDeletionConfirmation.requiredPhrase,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.error,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 18),
            CheckboxListTile(
              value: _understood,
              enabled: !_deleting,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                'Je comprends que cette suppression est '
                'définitive et irréversible.',
              ),
              onChanged: (value) {
                setState(() => _understood = value ?? false);
              },
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: _deleting ? null : _deleteAccount,
              icon: _deleting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.delete_forever_outlined),
              label: Text(
                _deleting
                    ? 'Suppression en cours…'
                    : 'Supprimer définitivement mon compte',
              ),
            ),
            if (_deleting) ...[
              const SizedBox(height: 14),
              const LinearProgressIndicator(),
              const SizedBox(height: 10),
              Text(
                'AutoClair supprime vos fichiers privés et vos données. '
                'Ne fermez pas cette page.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeletedDataRow extends StatelessWidget {
  const _DeletedDataRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.softPrimary,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
