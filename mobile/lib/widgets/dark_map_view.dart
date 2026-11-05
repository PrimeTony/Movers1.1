import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_theme.dart';

class DarkMapView extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final List<LatLng>? routePoints;
  final LatLng? pickupPoint;
  final LatLng? destinationPoint;
  final LatLng? driverPoint;
  final bool showRadar;

  const DarkMapView({
    super.key,
    this.initialCenter = const LatLng(-26.1200, 28.0500),
    this.initialZoom = 13.5,
    this.routePoints,
    this.pickupPoint,
    this.destinationPoint,
    this.driverPoint,
    this.showRadar = false,
  });

  @override
  State<DarkMapView> createState() => _DarkMapViewState();
}

class _DarkMapViewState extends State<DarkMapView> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant DarkMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fitPoints();
  }

  void _fitPoints() {
    if (widget.pickupPoint != null && widget.destinationPoint != null) {
      final midLat =
          (widget.pickupPoint!.latitude + widget.destinationPoint!.latitude) /
          2;
      final midLon =
          (widget.pickupPoint!.longitude + widget.destinationPoint!.longitude) /
          2;
      _mapController.move(LatLng(midLat, midLon), 12.8);
    } else if (widget.pickupPoint != null) {
      _mapController.move(widget.pickupPoint!, 14.5);
    } else if (widget.destinationPoint != null) {
      _mapController.move(widget.destinationPoint!, 14.5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: widget.initialCenter,
            initialZoom: widget.initialZoom,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            // Dark Mode OpenStreetMap Layer
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.movers.app',
              tileBuilder: darkModeTileBuilder,
            ),

            // Route Polyline connecting the two searched points
            if (widget.routePoints != null && widget.routePoints!.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.routePoints!,
                    strokeWidth: 4.5,
                    color: AppTheme.accentLime,
                    borderColor: AppTheme.pureBlack,
                    borderStrokeWidth: 1.5,
                  ),
                ],
              ),

            // Map Markers Layer
            MarkerLayer(
              markers: [
                // 1. PICKUP MARKER (Green Accent with Pin)
                if (widget.pickupPoint != null)
                  Marker(
                    point: widget.pickupPoint!,
                    width: 44,
                    height: 44,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.statusGreen,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.statusGreen.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.person_pin,
                            color: AppTheme.pureBlack,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 2. DESTINATION MARKER (Accent Lime Flag)
                if (widget.destinationPoint != null)
                  Marker(
                    point: widget.destinationPoint!,
                    width: 44,
                    height: 44,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentLime,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.accentLime.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.flag_rounded,
                            color: AppTheme.pureBlack,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 3. MOVING DRIVER CAR MARKER
                if (widget.driverPoint != null)
                  Marker(
                    point: widget.driverPoint!,
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.pureBlack,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.accentLime,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.directions_car,
                          color: AppTheme.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Live Radar Scanning Visual Effect
        if (widget.showRadar)
          Center(
            child: IgnorePointer(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentLime.withOpacity(0.15),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentLime.withOpacity(0.25),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.accentLime.withOpacity(0.40),
                        width: 1.5,
                      ),
                    ),
                  ),
                  Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentLime,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Dark Mode Inversion filter for OpenStreetMap tiles
Widget darkModeTileBuilder(
  BuildContext context,
  Widget tileWidget,
  TileImage tile,
) {
  return ColorFiltered(
    colorFilter: const ColorFilter.matrix(<double>[
      -0.2126,
      -0.7152,
      -0.0722,
      0,
      255,
      -0.2126,
      -0.7152,
      -0.0722,
      0,
      255,
      -0.2126,
      -0.7152,
      -0.0722,
      0,
      255,
      0,
      0,
      0,
      1,
      0,
    ]),
    child: tileWidget,
  );
}
