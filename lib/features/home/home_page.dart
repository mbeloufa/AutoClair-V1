import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../../core/widgets/app_logo.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _vehicleService = VehicleService();
  Vehicle? _primaryVehicle;
  bool _loadingVehicle = true;

  @override
  void initState() {
    super.initState();
    _loadPrimaryVehicle();
  }

  Future<void> _loadPrimaryVehicle() async {
    try {
      final vehicles = await _vehicleService.fetchVehicles();
      if (mounted) {
        setState(() {
          _primaryVehicle = vehicles.isEmpty ? null : vehicles.first;
        });
      }
    } on VehicleServiceException {
      if (mounted) setState(() => _primaryVehicle = null);
    } finally {
      if (mounted) setState(() => _loadingVehicle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name']?.toString().trim();
    final displayName = fullName == null || fullName.isEmpty
        ? 'Bienvenue'
        : 'Bonjour $fullName';

    return Scaffold(
      appBar: AppBar(
        title: const AppLogo(compact: true),
        backgroundColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPrimaryVehicle,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Text(
              displayName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'AutoClair vous aide à comprendre les documents liés à votre véhicule.',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 28),
            Text('Mon véhicule', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            _buildVehicleSection(context),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _primaryVehicle == null
                  ? null
                  : () => context.push('/documents/new'),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Ajouter un document'),
            ),
            if (_primaryVehicle == null) ...[
              const SizedBox(height: 8),
              Text(
                'Ajoutez un véhicule avant de transmettre un document.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.description_outlined,
                    size: 52,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune analyse pour le moment',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Les documents transmis apparaîtront dans l'historique après l'ajout du module d'analyse.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildVehicleSection(BuildContext context) {
    if (_loadingVehicle) {
      return const SizedBox(
        height: 130,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final vehicle = _primaryVehicle;
    if (vehicle == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.directions_car_outlined,
              size: 44,
              color: AppColors.primary,
            ),
            const SizedBox(height: 14),
            const Text(
              "Vous n'avez pas encore enregistré de véhicule.",
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () async {
                final changed = await context.push<bool>('/vehicles/new');
                if (changed == true) await _loadPrimaryVehicle();
              },
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un véhicule'),
            ),
          ],
        ),
      );
    }

    final details = <String>[
      if (vehicle.vehicleYear != null) vehicle.vehicleYear.toString(),
      if (vehicle.fuelType?.trim().isNotEmpty == true) vehicle.fuelType!,
      if (vehicle.mileage != null) '${vehicle.mileage} km',
    ];

    return InkWell(
      onTap: () async {
        final changed = await context.push<bool>(
          '/vehicles/${vehicle.id}/edit',
        );
        if (changed == true) await _loadPrimaryVehicle();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.directions_car,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    vehicle.displayName,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  if (vehicle.nickname?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 3),
                    Text(
                      vehicle.makeAndModel,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  if (details.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      details.join(' • '),
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }
}
