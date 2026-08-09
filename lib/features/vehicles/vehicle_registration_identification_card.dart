import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import 'vehicle_identification_result.dart';
import 'vehicle_identification_service.dart';
import 'vehicle_registration.dart';

typedef VehicleRegistrationLookup =
    Future<VehicleIdentificationResult> Function(String registration);

class VehicleRegistrationIdentificationCard extends StatefulWidget {
  const VehicleRegistrationIdentificationCard({
    required this.controller,
    required this.enabled,
    required this.onIdentified,
    this.lookup,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<VehicleIdentificationResult> onIdentified;
  final VehicleRegistrationLookup? lookup;

  @override
  State<VehicleRegistrationIdentificationCard> createState() =>
      _VehicleRegistrationIdentificationCardState();
}

class _VehicleRegistrationIdentificationCardState
    extends State<VehicleRegistrationIdentificationCard> {
  bool _loading = false;
  String? _message;
  bool _messageIsError = false;
  VehicleIdentificationResult? _result;

  VehicleRegistrationLookup get _lookup =>
      widget.lookup ?? VehicleIdentificationService().identify;

  Future<void> _identify() async {
    if (_loading || !widget.enabled) return;

    final validation = VehicleRegistration.lookupValidationMessage(
      widget.controller.text,
    );

    if (validation != null) {
      setState(() {
        _message = validation;
        _messageIsError = true;
        _result = null;
      });
      return;
    }

    final formatted = VehicleRegistration.format(widget.controller.text);
    widget.controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );

    setState(() {
      _loading = true;
      _message = null;
      _messageIsError = false;
      _result = null;
    });

    try {
      final result = await _lookup(formatted);
      if (!mounted) return;

      widget.onIdentified(result);

      setState(() {
        _result = result;
        _message = 'Informations proposées. Vérifiez-les avant d’enregistrer.';
        _messageIsError = false;
      });
    } on VehicleIdentificationException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message;
        _messageIsError = true;
        _result = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            "L'identification automatique est temporairement indisponible. "
            'Vous pouvez continuer manuellement.';
        _messageIsError = true;
        _result = null;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.pin_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Identifier par immatriculation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'AutoClair peut proposer la marque, le modèle, l’année et '
            'la motorisation. Vous gardez la main avant l’enregistrement.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: widget.controller,
            enabled: widget.enabled && !_loading,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            inputFormatters: [LengthLimitingTextInputFormatter(15)],
            onFieldSubmitted: (_) => _identify(),
            decoration: const InputDecoration(
              labelText: 'Immatriculation',
              hintText: 'Ex. AB-123-CD',
              prefixIcon: Icon(Icons.pin_outlined),
              helperText: 'Facultatif — saisie manuelle toujours possible',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: widget.enabled && !_loading ? _identify : null,
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(
                _loading
                    ? 'Identification en cours…'
                    : 'Identifier mon véhicule',
              ),
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            _StatusMessage(message: _message!, isError: _messageIsError),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.successSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.displayName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (result.vehicleYear != null)
                              result.vehicleYear.toString(),
                            ?result.fuelType,
                          ].join(' • '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Source : ${result.sourceLabel}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    final background = isError ? AppColors.errorSoft : AppColors.successSoft;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.info_outline : Icons.check_circle_outline,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
