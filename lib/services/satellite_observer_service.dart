import 'dart:async';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../models/discovery.dart';
import 'satellite_service.dart';

class SatelliteObserverState {
  final ObserverLocation? location;
  final bool usingDeviceLocation;
  final String status;

  const SatelliteObserverState({
    required this.location,
    required this.usingDeviceLocation,
    required this.status,
  });
}

class DeviceAimState {
  final double heading;
  final double elevation;

  const DeviceAimState({
    required this.heading,
    required this.elevation,
  });
}

class SatelliteObserverService {
  final SatelliteService _satelliteService;

  SatelliteObserverService({SatelliteService? satelliteService})
      : _satelliteService = satelliteService ?? SatelliteService();

  Stream<double> get headingStream {
    return magnetometerEventStream().map((event) {
      final heading = atan2(event.y, event.x) * 180 / pi;
      return (heading + 360) % 360;
    });
  }

  Stream<DeviceAimState> get deviceAimStream {
    late StreamController<DeviceAimState> controller;
    StreamSubscription<double>? headingSubscription;
    StreamSubscription<AccelerometerEvent>? elevationSubscription;
    double? heading;
    double? elevation;

    void emit() {
      if (heading == null || elevation == null || controller.isClosed) return;
      controller.add(DeviceAimState(heading: heading!, elevation: elevation!));
    }

    controller = StreamController<DeviceAimState>(
      onListen: () {
        headingSubscription = headingStream.listen((value) {
          heading = value;
          emit();
        });
        elevationSubscription = accelerometerEventStream().listen((event) {
          final horizontal = sqrt(event.x * event.x + event.y * event.y);
          final pitch = atan2(-event.z, horizontal) * 180 / pi;
          elevation = pitch.clamp(0, 90).toDouble();
          emit();
        });
      },
      onCancel: () async {
        await headingSubscription?.cancel();
        await elevationSubscription?.cancel();
      },
    );
    return controller.stream;
  }

  Future<SatelliteObserverState> resolveLocation(String grid) async {
    final gridLocation = _satelliteService.observerFromGrid(grid);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return SatelliteObserverState(
          location: gridLocation,
          usingDeviceLocation: false,
          status:
              gridLocation == null ? '定位服务未开启，且未设置有效 Grid' : '定位服务未开启，已使用 Grid',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return SatelliteObserverState(
          location: gridLocation,
          usingDeviceLocation: false,
          status:
              gridLocation == null ? '定位权限未授权，且未设置有效 Grid' : '定位权限未授权，已使用 Grid',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return SatelliteObserverState(
        location: ObserverLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          altitudeKm: max(0, position.altitude) / 1000,
          label: 'GPS ${position.latitude.toStringAsFixed(4)}, '
              '${position.longitude.toStringAsFixed(4)}',
          source: 'GPS',
        ),
        usingDeviceLocation: true,
        status: '正在使用设备定位',
      );
    } catch (_) {
      return SatelliteObserverState(
        location: gridLocation,
        usingDeviceLocation: false,
        status: gridLocation == null ? '无法获取定位，且未设置有效 Grid' : '无法获取定位，已使用 Grid',
      );
    }
  }
}
