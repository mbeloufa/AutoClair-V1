import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bottom_nav.dart';
import '../vehicles/vehicle.dart';
import '../vehicles/vehicle_card.dart';
import '../vehicles/vehicle_service.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({super.key});

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final _service = VehicleService();

  List<Vehicle> _vehicles = const [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final vehicles = await _service.fetchVehicles();
      if (mounted) {
        setState(() => _vehicles = vehicles);
      }
    } on VehicleServiceException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openCreate() async {
    final changed = await context.push<bool>('/vehicles/new');
    if (changed == true) {
      await _loadVehicles();
    }
  }

  Future<void> _openEdit(Vehicle vehicle) async {
    final changed = await context.push<bool>('/vehicles/${vehicle.id}/edit');
    if (changed == true) {
      await _loadVehicles();
    }
  }

  Future<void> _deleteVehicle(Vehicle vehicle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer ce véhicule ?'),
          content: Text(
            'Le véhicule « ${vehicle.displayName} » sera supprimé. '
            'Cette action est définitive.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _service.deleteVehicle(vehicle.id);
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le véhicule a été supprimé.')),
      );
      await _loadVehicles();
    } on VehicleServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  void _handleAction(Vehicle vehicle, VehicleCardAction action) {
    switch (action) {
      case VehicleCardAction.edit:
        _openEdit(vehicle);
      case VehicleCardAction.delete:
        _deleteVehicle(vehicle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes véhicules'),
        actions: [
          IconButton(
            onPressed: _openCreate,
            icon: const Icon(Icons.add),
            tooltip: 'Ajouter un véhicule',
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _vehicles.isEmpty || _loading
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreate,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 1),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 54,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton.tonal(
                onPressed: _loadVehicles,
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      );
    }

    if (_vehicles.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(
                  Icons.directions_car_outlined,
                  size: 52,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Ajoutez votre premier véhicule',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Il servira à classer vos devis, factures et analyses.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openCreate,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un véhicule'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVehicles,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        itemCount: _vehicles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          final vehicle = _vehicles[index];
          return VehicleCard(
            vehicle: vehicle,
            onTap: () => _openEdit(vehicle),
            onAction: (action) => _handleAction(vehicle, action),
          );
        },
      ),
    );
  }
}
