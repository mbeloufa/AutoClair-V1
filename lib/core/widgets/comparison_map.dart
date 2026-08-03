import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

class ComparisonMapMarkerData {
  const ComparisonMapMarkerData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String id;
  final double latitude;
  final double longitude;
  final String label;
  final IconData icon;
  final Color color;

  bool get hasFiniteCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  LatLng get point => LatLng(latitude, longitude);
}

class ComparisonMapView extends StatefulWidget {
  const ComparisonMapView({
    required this.userLatitude,
    required this.userLongitude,
    required this.markers,
    required this.selectedMarkerId,
    required this.onMarkerSelected,
    required this.sheetBuilder,
    super.key,
    this.initialSheetSize = 0.26,
    this.minSheetSize = 0.18,
    this.maxSheetSize = 0.82,
  });

  final double userLatitude;
  final double userLongitude;
  final List<ComparisonMapMarkerData> markers;
  final String? selectedMarkerId;
  final ValueChanged<String> onMarkerSelected;
  final Widget Function(BuildContext context, ScrollController controller)
  sheetBuilder;
  final double initialSheetSize;
  final double minSheetSize;
  final double maxSheetSize;

  @override
  State<ComparisonMapView> createState() => _ComparisonMapViewState();
}

class _ComparisonMapViewState extends State<ComparisonMapView> {
  static const _tileUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const _userAgentPackageName = 'fr.autoclair.autoclair_app';

  final MapController _mapController = MapController();
  bool _mapReady = false;

  LatLng get _userPoint => LatLng(widget.userLatitude, widget.userLongitude);

  List<ComparisonMapMarkerData> get _validMarkers => widget.markers
      .where((marker) => marker.hasFiniteCoordinates)
      .toList(growable: false);

  String get _pointsSignature {
    final markerSignature = _validMarkers
        .map(
          (marker) =>
              '${marker.id}:${marker.latitude.toStringAsFixed(6)}:${marker.longitude.toStringAsFixed(6)}',
        )
        .join('|');
    return '${widget.userLatitude.toStringAsFixed(6)}:'
        '${widget.userLongitude.toStringAsFixed(6)}|$markerSignature';
  }

  @override
  void didUpdateWidget(covariant ComparisonMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldMarkerSignature = oldWidget.markers
        .where((marker) => marker.hasFiniteCoordinates)
        .map(
          (marker) =>
              '${marker.id}:${marker.latitude.toStringAsFixed(6)}:${marker.longitude.toStringAsFixed(6)}',
        )
        .join('|');
    final oldSignature =
        '${oldWidget.userLatitude.toStringAsFixed(6)}:'
        '${oldWidget.userLongitude.toStringAsFixed(6)}|$oldMarkerSignature';

    if (_mapReady && oldSignature != _pointsSignature) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
      return;
    }

    if (_mapReady &&
        oldWidget.selectedMarkerId != widget.selectedMarkerId &&
        widget.selectedMarkerId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusSelected(widget.selectedMarkerId!);
      });
    }
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _onMapReady() {
    _mapReady = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitAll());
  }

  void _fitAll() {
    if (!_mapReady) return;

    final points = <LatLng>[
      _userPoint,
      ..._validMarkers.map((marker) => marker.point),
    ];

    if (points.length == 1) {
      _mapController.move(points.first, 13.5);
      return;
    }

    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.fromLTRB(54, 86, 54, 190),
        minZoom: 5,
        maxZoom: 15.5,
      ),
    );
  }

  void _focusUser() {
    if (!_mapReady) return;
    _mapController.move(
      _userPoint,
      math.max(_mapController.camera.zoom, 14).toDouble(),
    );
  }

  void _focusSelected(String markerId) {
    if (!_mapReady) return;

    ComparisonMapMarkerData? selected;
    for (final marker in _validMarkers) {
      if (marker.id == markerId) {
        selected = marker;
        break;
      }
    }
    if (selected == null) return;

    _mapController.move(
      selected.point,
      math.max(_mapController.camera.zoom, 13.8).toDouble(),
      offset: const Offset(0, -92),
    );
  }

  void _selectMarker(ComparisonMapMarkerData marker) {
    widget.onMarkerSelected(marker.id);
    _focusSelected(marker.id);
  }

  Future<void> _openAttribution() async {
    await launchUrl(
      Uri.parse('https://www.openstreetmap.org/copyright'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = _validMarkers;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.softPrimary,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _userPoint,
                initialZoom: 12.5,
                minZoom: 4,
                maxZoom: 19,
                backgroundColor: AppColors.softPrimary,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onMapReady: _onMapReady,
              ),
              children: [
                TileLayer(
                  urlTemplate: _tileUrl,
                  userAgentPackageName: _userAgentPackageName,
                  maxNativeZoom: 19,
                  maxZoom: 19,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userPoint,
                      width: 34,
                      height: 34,
                      child: const _UserPositionMarker(),
                    ),
                    for (final marker in markers)
                      Marker(
                        point: marker.point,
                        width: 126,
                        height: 64,
                        alignment: Alignment.bottomCenter,
                        child: _PriceMapMarker(
                          data: marker,
                          selected: marker.id == widget.selectedMarkerId,
                          onTap: () => _selectMarker(marker),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _MapAttributionButton(onTap: _openAttribution),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Column(
                children: [
                  _MapControlButton(
                    tooltip: 'Afficher tous les résultats',
                    icon: Icons.zoom_out_map_rounded,
                    onPressed: _fitAll,
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    tooltip: 'Recentrer sur ma position',
                    icon: Icons.my_location_rounded,
                    onPressed: _focusUser,
                  ),
                ],
              ),
            ),
            DraggableScrollableSheet(
              initialChildSize: widget.initialSheetSize,
              minChildSize: widget.minSheetSize,
              maxChildSize: widget.maxSheetSize,
              snap: true,
              snapSizes: [widget.minSheetSize, 0.40, widget.maxSheetSize],
              builder: (context, scrollController) {
                return Material(
                  color: AppColors.surface,
                  elevation: 18,
                  shadowColor: Colors.black.withValues(alpha: 0.24),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(26),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Expanded(
                        child: widget.sheetBuilder(context, scrollController),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceMapMarker extends StatelessWidget {
  const _PriceMapMarker({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final ComparisonMapMarkerData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : data.color;
    final background = selected ? data.color : Colors.white;

    return Semantics(
      button: true,
      selected: selected,
      label: data.label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: selected ? 1.08 : 1,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? data.color
                        : data.color.withValues(alpha: 0.40),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.16),
                      blurRadius: selected ? 14 : 9,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(data.icon, size: 17, color: foreground),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        data.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              CustomPaint(
                size: const Size(18, 9),
                painter: _MarkerTailPainter(color: background),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarkerTailPainter extends CustomPainter {
  const _MarkerTailPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _MarkerTailPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _UserPositionMarker extends StatelessWidget {
  const _UserPositionMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.info.withValues(alpha: 0.20),
      ),
      child: Center(
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.info,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 7,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(14),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

class _MapAttributionButton extends StatelessWidget {
  const _MapAttributionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Text(
            '© OpenStreetMap',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.text,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
