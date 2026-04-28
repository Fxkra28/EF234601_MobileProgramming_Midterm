import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  Stream<bool> get onlineStream => _connectivity.onConnectivityChanged
      .map((results) => results.any((r) => r != ConnectivityResult.none));

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((r) => r != ConnectivityResult.none);
  }
}
