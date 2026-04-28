import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../services/location_service.dart';

class PickedLocation {
  final double latitude;
  final double longitude;
  final String? name;

  const PickedLocation({
    required this.latitude,
    required this.longitude,
    this.name,
  });
}

class LocationPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;
  final String? initialName;

  const LocationPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
    this.initialName,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  LatLng? _picked;
  String? _pickedName;
  bool _gpsBusy = false;
  bool _searching = false;
  List<_NominatimHit> _results = [];

  static const LatLng _fallbackCenter = LatLng(-7.2575, 112.7521); // Surabaya

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _picked = LatLng(widget.initialLatitude!, widget.initialLongitude!);
      _pickedName = widget.initialName;
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _runSearch(query.trim());
    });
  }

  Future<void> _runSearch(String query) async {
    setState(() => _searching = true);
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeQueryComponent(query)}'
          '&format=json'
          '&addressdetails=1'
          '&limit=8');
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'ETS1Flutter/1.0 (com.example.ets1)',
          'Accept-Language': 'en,id',
        },
      );
      if (!mounted) return;
      if (response.statusCode != 200) {
        setState(() {
          _results = [];
          _searching = false;
        });
        return;
      }
      final data = jsonDecode(response.body) as List<dynamic>;
      setState(() {
        _results = data.map((e) {
          final m = e as Map<String, dynamic>;
          return _NominatimHit(
            displayName: m['display_name'] as String,
            lat: double.parse(m['lat'] as String),
            lon: double.parse(m['lon'] as String),
            type: m['type'] as String?,
          );
        }).toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _searching = false;
      });
    }
  }

  void _selectResult(_NominatimHit hit) {
    final ll = LatLng(hit.lat, hit.lon);
    setState(() {
      _picked = ll;
      _pickedName = hit.displayName;
      _results = [];
      _searchCtrl.text = hit.displayName;
    });
    _mapController.move(ll, 16);
    FocusScope.of(context).unfocus();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _gpsBusy = true);
    final result = await LocationService.instance.getCurrentPosition();
    if (!mounted) return;
    setState(() => _gpsBusy = false);

    switch (result.status) {
      case LocationResultStatus.ok:
        final pos = result.position!;
        final ll = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _picked = ll;
          _pickedName = null;
          _searchCtrl.clear();
          _results = [];
        });
        _mapController.move(ll, 16);
        unawaited(_reverseGeocode(ll));
        break;
      case LocationResultStatus.deniedForever:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message ?? 'Location permission denied.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => LocationService.instance.openSettings(),
            ),
          ),
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.message ?? 'Could not get location.')),
        );
    }
  }

  Future<void> _reverseGeocode(LatLng point) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?lat=${point.latitude}&lon=${point.longitude}'
          '&format=json&zoom=18&addressdetails=1');
      final response = await http.get(
        uri,
        headers: const {
          'User-Agent': 'ETS1Flutter/1.0 (com.example.ets1)',
          'Accept-Language': 'en,id',
        },
      );
      if (!mounted || response.statusCode != 200) return;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final name = data['display_name'] as String?;
      if (name != null) {
        setState(() => _pickedName = name);
      }
    } catch (_) {}
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _picked = point;
      _pickedName = null;
      _searchCtrl.clear();
      _results = [];
    });
    FocusScope.of(context).unfocus();
    unawaited(_reverseGeocode(point));
  }

  void _confirm() {
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search a place or tap on the map first.')),
      );
      return;
    }
    Navigator.of(context).pop(PickedLocation(
      latitude: _picked!.latitude,
      longitude: _picked!.longitude,
      name: _pickedName,
    ));
  }

  void _clear() {
    setState(() {
      _picked = null;
      _pickedName = null;
      _searchCtrl.clear();
      _results = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _picked ?? _fallbackCenter;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF4A90E2),
        title: const Text(
          'Pick Location',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF4A90E2),
          ),
        ),
        actions: [
          if (_picked != null)
            IconButton(
              tooltip: 'Clear pin',
              icon: const Icon(Icons.delete_outline),
              onPressed: _clear,
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (q) => _runSearch(q.trim()),
              decoration: InputDecoration(
                hintText: 'Search a place (e.g. "ITS Surabaya")',
                prefixIcon: _searching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.search, color: Color(0xFF4A90E2)),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _results = [];
                          });
                        },
                      ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
          ),
          if (_results.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _results.length,
                separatorBuilder: (_, _) => Divider(
                    height: 1, color: Colors.grey.shade100),
                itemBuilder: (_, i) {
                  final r = _results[i];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place,
                        size: 20, color: Color(0xFF4A90E2)),
                    title: Text(
                      r.displayName,
                      style: const TextStyle(fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => _selectResult(r),
                  );
                },
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: initialCenter,
                    initialZoom: _picked == null ? 5 : 16,
                    onTap: _onMapTap,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.ets1',
                      maxZoom: 19,
                    ),
                    if (_picked != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _picked!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_on,
                              color: Color(0xFF4A90E2),
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (_pickedName != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.location_on,
                              size: 18, color: Color(0xFF4A90E2)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _pickedName!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF4A90E2),
                    onPressed: _gpsBusy ? null : _useCurrentLocation,
                    child: _gpsBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _picked == null ? null : _confirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text(
                    'Use this location',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NominatimHit {
  final String displayName;
  final double lat;
  final double lon;
  final String? type;

  const _NominatimHit({
    required this.displayName,
    required this.lat,
    required this.lon,
    this.type,
  });
}
