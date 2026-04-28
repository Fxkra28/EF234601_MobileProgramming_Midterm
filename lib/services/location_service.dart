import 'package:geolocator/geolocator.dart';

enum LocationResultStatus { ok, serviceDisabled, denied, deniedForever, error }

class LocationResult {
  final LocationResultStatus status;
  final Position? position;
  final String? message;

  const LocationResult(this.status, {this.position, this.message});
}

class LocationService {
  static final LocationService instance = LocationService._();
  LocationService._();

  Future<LocationResult> getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const LocationResult(
          LocationResultStatus.serviceDisabled,
          message: 'Location services are disabled.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(
          LocationResultStatus.denied,
          message: 'Location permission denied.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(
          LocationResultStatus.deniedForever,
          message: 'Location permission permanently denied. Open settings to enable.',
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      return LocationResult(LocationResultStatus.ok, position: pos);
    } catch (e) {
      return LocationResult(
        LocationResultStatus.error,
        message: e.toString(),
      );
    }
  }

  Future<bool> openSettings() => Geolocator.openAppSettings();
}
