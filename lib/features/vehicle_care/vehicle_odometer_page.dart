import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_care_service.dart';

class VehicleOdometerPage extends StatefulWidget {
  const VehicleOdometerPage({
    required this.vehicleId,
    this.currentMileage,
    super.key,
  });

  final String vehicleId;
  final int? currentMileage;

  @override
  State<VehicleOdometerPage> createState() => _VehicleOdometerPageState();
}

class _VehicleOdometerPageState extends State<VehicleOdometerPage> {
  final _formKey = GlobalKey<FormState>();
  final _service = VehicleCareService();
  late final TextEditingController _mileageController;
  DateTime _readingAt = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mileageController = TextEditingController(
      text: widget.currentMileage?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _mileageController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _readingAt,
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Date du relevé',
    );
    if (date != null && mounted) {
      setState(
        () => _readingAt = DateTime(date.year, date.month, date.day, 12),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final mileage = int.parse(_mileageController.text.replaceAll(' ', ''));

    setState(() => _saving = true);
    try {
      await _service.addOdometerReading(
        vehicleId: widget.vehicleId,
        mileage: mileage,
        readingAt: _readingAt,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Kilométrage mis à jour.')));
      Navigator.of(context).pop(true);
    } on VehicleCareException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mettre à jour le kilométrage')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.softPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.speed_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Un kilométrage récent améliore les échéances, le '
                        'budget prévisionnel et les conseils de revente.',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _mileageController,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kilométrage actuel',
                  suffixText: 'km',
                  prefixIcon: Icon(Icons.speed_outlined),
                ),
                validator: (value) {
                  final parsed = int.tryParse(
                    (value ?? '').replaceAll(' ', ''),
                  );
                  if (parsed == null || parsed < 0) {
                    return 'Saisissez un kilométrage valide.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              InkWell(
                onTap: _saving ? null : _selectDate,
                borderRadius: BorderRadius.circular(16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date du relevé',
                    prefixIcon: Icon(Icons.calendar_today_outlined),
                  ),
                  child: Text(_formatDate(_readingAt)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "Si le relevé est inférieur à l'historique connu, AutoClair "
                "le conservera comme anomalie à vérifier sans diminuer le "
                "kilométrage principal du véhicule.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
