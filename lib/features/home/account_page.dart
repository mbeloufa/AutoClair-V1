import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../auth/auth_service.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _authService = AuthService();
  bool _loading = false;

  Future<void> _logout() async {
    if (_loading) return;

    setState(() => _loading = true);

    try {
      await _authService.logout();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez été déconnecté.')),
      );
      context.go('/login');
    } on AuthServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString().trim();
    final displayName = fullName == null || fullName.isEmpty
        ? 'Utilisateur AutoClair'
        : fullName;
    final email = user?.email?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Mon compte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          _ProfileHeader(
            displayName: displayName,
            email: email,
            initials: _initials(displayName),
          ),
          const SizedBox(height: 24),
          _AccountSection(
            title: 'Mon espace',
            children: [
              _SettingsTile(
                icon: Icons.directions_car_outlined,
                title: 'Mes véhicules',
                subtitle: 'Consulter et mettre à jour mes véhicules',
                onTap: () => context.go('/vehicles'),
              ),
              _SettingsTile(
                icon: Icons.history_outlined,
                title: 'Mes documents et analyses',
                subtitle: 'Retrouver mon historique AutoClair',
                onTap: () => context.go('/history'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _AccountSection(
            title: 'Sécurité et confidentialité',
            children: [
              _SettingsTile(
                icon: Icons.verified_user_outlined,
                title: 'Session sécurisée',
                subtitle: 'Votre connexion est protégée par Supabase Auth',
                statusIcon: Icons.check_circle,
                statusColor: AppColors.success,
              ),
              _SettingsTile(
                icon: Icons.lock_outline,
                title: 'Documents privés',
                subtitle: 'Aucun fichier ne reçoit d’adresse publique',
                statusIcon: Icons.check_circle,
                statusColor: AppColors.success,
              ),
              _SettingsTile(
                icon: Icons.manage_accounts_outlined,
                title: 'Contrôle de vos données',
                subtitle: 'Vous pouvez supprimer vos documents ou votre compte',
                statusIcon: Icons.check_circle,
                statusColor: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _AboutCard(),
          const SizedBox(height: 22),
          FilledButton.tonalIcon(
            onPressed: _loading ? null : _logout,
            icon: _loading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
          const SizedBox(height: 32),
          Text(
            'Zone sensible',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: 10),
          _DangerCard(
            onDeleteAccount: _loading
                ? null
                : () => context.push('/account/delete'),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 3),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return 'AC';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }

    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.initials,
  });

  final String displayName;
  final String email;
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.16),
            child: Text(
              initials,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Compte sécurisé',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                children[index],
                if (index < children.length - 1)
                  const Divider(indent: 72, endIndent: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.statusIcon,
    this.statusColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final IconData? statusIcon;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.softPrimary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textMuted)
            else if (statusIcon != null)
              Icon(
                statusIcon,
                color: statusColor ?? AppColors.success,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.infoSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.info),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À propos d’AutoClair',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 5),
                Text(
                  'Version 1.1 • Une aide à la lecture de vos documents '
                  'automobiles. AutoClair ne remplace pas un diagnostic '
                  'professionnel.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerCard extends StatelessWidget {
  const _DangerCard({required this.onDeleteAccount});

  final VoidCallback? onDeleteAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.errorSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.delete_forever_outlined, color: AppColors.error),
              SizedBox(width: 10),
              Text(
                'Suppression du compte',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Supprime définitivement votre compte, vos véhicules, vos '
            'documents privés et vos analyses.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.error,
              side: const BorderSide(color: AppColors.error),
            ),
            onPressed: onDeleteAccount,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Supprimer mon compte'),
          ),
        ],
      ),
    );
  }
}
