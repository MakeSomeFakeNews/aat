import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../controllers/location_controller.dart';
import '../controllers/bluetooth_controller.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  Timer? _simulationTimer;
  double _simulationAngle = 0.0;
  LatLng? _simulatedLocation;
  bool _isSimulating = false;
  static const double _simulationRadius = 0.001; // 约100米半径
  static const int _simulationInterval = 1000; // 1秒更新一次
  LatLng? selectedLocation;
  final LocationController locationController = Get.put(LocationController());
  final BluetoothController bluetoothController = Get.find();
  final MapController mapController = MapController();

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startSimulation() {
    // 优先使用家的位置，如果没有则使用当前位置
    final homeLocation = locationController.homeLocation.value;
    final currentLocation = locationController.currentLocation.value;
    final centerLocation = homeLocation ?? currentLocation;
    
    if (centerLocation == null) return;

    setState(() {
      _isSimulating = true;
      _simulatedLocation = centerLocation;
    });

    _simulationTimer = Timer.periodic(Duration(milliseconds: _simulationInterval), (timer) {
      if (!_isSimulating || bluetoothController.connectedDevice.value == null) {
        _stopSimulation();
        return;
      }

      setState(() {
        // 更新角度
        _simulationAngle += 0.1; // 每次增加0.1弧度，大约5.7度
        if (_simulationAngle >= 2 * pi) _simulationAngle = 0;

        // 计算新位置
        final newLat = centerLocation.latitude + _simulationRadius * cos(_simulationAngle);
        final newLng = centerLocation.longitude + _simulationRadius * sin(_simulationAngle);
        _simulatedLocation = LatLng(newLat, newLng);
      });

      // 发送新位置
      if (_simulatedLocation != null) {
        final locationData = locationController.locationToBytes(
          latitude: _simulatedLocation!.latitude,
          longitude: _simulatedLocation!.longitude,
          type: LocationController.TYPE_CURRENT,
        );
        if (locationData.isNotEmpty) {
          bluetoothController.sendLocation(locationData);
        }
      }
    });
  }

  void _stopSimulation() {
    _simulationTimer?.cancel();
    setState(() {
      _isSimulating = false;
      _simulatedLocation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 地图
          Obx(() {
            if (locationController.isLoading.value) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在获取位置...'),
                  ],
                ),
              );
            }

            final location = locationController.currentLocation.value;
            if (location == null) {
              return const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('无法获取位置'),
                  ],
                ),
              );
            }

            return FlutterMap(
              mapController: mapController,
              options: MapOptions(
                initialCenter: LatLng(location.latitude, location.longitude),
                initialZoom: 15,
                minZoom: 6,
                maxZoom: 18,
                onTap: (tapPosition, point) {
                  // 显示对话框让用户选择设置为当前位置或家
                  Get.dialog(
                    AlertDialog(
                      title: const Text('设置位置'),
                      content: const Text('请选择要设置的位置类型'),
                      actions: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedLocation = point;
                            });
                            Get.back();
                          },
                          child: const Text('当前位置'),
                        ),
                        TextButton(
                          onPressed: () {
                            locationController.setHomeLocation(point);
                            Get.back();
                          },
                          child: const Text('设为家'),
                        ),
                      ],
                    ),
                  );
                },
              ),
              children: [
                // 影像底图
                TileLayer(
                  tileProvider: NetworkTileProvider(),
                  urlTemplate: 'https://t{s}.tianditu.gov.cn/img_w/wmts'
                      '?SERVICE=WMTS'
                      '&REQUEST=GetTile'
                      '&VERSION=1.0.0'
                      '&LAYER=img'
                      '&STYLE=default'
                      '&TILEMATRIXSET=w'
                      '&FORMAT=tiles'
                      '&TILEMATRIX={z}'
                      '&TILEROW={y}'
                      '&TILECOL={x}'
                      '&tk=7b6c4639d43c1623aadf28127d053d88',
                  subdomains: const ['0', '1', '2', '3', '4', '5', '6', '7'],
                ),
                // 影像注记
                TileLayer(
                  tileProvider: NetworkTileProvider(),
                  urlTemplate: 'https://t{s}.tianditu.gov.cn/cia_w/wmts'
                      '?SERVICE=WMTS'
                      '&REQUEST=GetTile'
                      '&VERSION=1.0.0'
                      '&LAYER=cia'
                      '&STYLE=default'
                      '&TILEMATRIXSET=w'
                      '&FORMAT=tiles'
                      '&TILEMATRIX={z}'
                      '&TILEROW={y}'
                      '&TILECOL={x}'
                      '&tk=7b6c4639d43c1623aadf28127d053d88',
                  subdomains: const ['0', '1', '2', '3', '4', '5', '6', '7'],
                ),
                // 标记层
                MarkerLayer(
                  markers: [
                    // 当前位置标记
                    Marker(
                      point: LatLng(location.latitude, location.longitude),
                      width: 80,
                      height: 80,
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.blue,
                        size: 40,
                      ),
                    ),
                    // 选中位置标记
                    if (selectedLocation != null)
                      Marker(
                        point: selectedLocation!,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    // 家的位置标记
                    if (locationController.homeLocation.value != null)
                      Marker(
                        point: locationController.homeLocation.value!,
                        width: 80,
                        height: 80,
                        child: const Icon(
                          Icons.home,
                          color: Colors.green,
                          size: 40,
                        ),
                      ),
                    // 模拟飞行位置标记
                    if (_simulatedLocation != null)
                      Marker(
                        point: _simulatedLocation!,
                        width: 16,
                        height: 16,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.yellow,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.orange,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          }),

          // 蓝牙状态
          Positioned(
            top: 16,
            right: 16,
            child: Obx(() {
              final isConnected = bluetoothController.connectedDevice.value != null;
              final deviceName = bluetoothController.connectedDevice.value?.name ?? '';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: isConnected ? Colors.blue : Colors.grey,
                      size: 20,
                    ),
                    if (isConnected) ...[  
                      const SizedBox(width: 8),
                      Text(
                        deviceName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ),

          // 底部按钮组
          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 旋转重置按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton.extended(
                    heroTag: 'resetRotation',
                    onPressed: () => mapController.rotate(0),
                    icon: const Icon(Icons.navigation),
                    label: const Text('重置方向'),
                  ),
                ),
                // 模拟飞行按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Obx(() {
                    final isConnected = bluetoothController.connectedDevice.value != null;
                    return FloatingActionButton.extended(
                      onPressed: isConnected
                          ? () {
                              if (_isSimulating) {
                                _stopSimulation();
                              } else {
                                _startSimulation();
                              }
                            }
                          : null,
                      icon: Icon(_isSimulating ? Icons.stop : Icons.play_arrow),
                      label: Text(_isSimulating ? '停止' : '开始模拟'),
                      backgroundColor: _isSimulating ? Colors.red : null,
                    );
                  }),
                ),
                // 发送位置按钮
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Obx(() {
                    final isConnected = bluetoothController.connectedDevice.value != null;
                    final currentLocation = locationController.currentLocation.value;
                    return FloatingActionButton.extended(
                      onPressed: isConnected && currentLocation != null
                          ? () {
                              final locationToSend = selectedLocation ?? currentLocation;
                              final locationData = locationController.locationToBytes(
                                latitude: locationToSend.latitude,
                                longitude: locationToSend.longitude,
                                type: LocationController.TYPE_CURRENT,
                              );
                              if (locationData.isNotEmpty) {
                                bluetoothController.sendLocation(locationData);
                              }
                            }
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('发送位置'),
                    );
                  }),
                ),
                // 发送家的位置按钮
                Obx(() {
                  final isConnected = bluetoothController.connectedDevice.value != null;
                  final currentLocation = locationController.currentLocation.value;
                  return FloatingActionButton.extended(
                    onPressed: isConnected && currentLocation != null
                        ? () {
                            final locationData = locationController.locationToBytes(
                              latitude: currentLocation.latitude,
                              longitude: currentLocation.longitude,
                              type: LocationController.TYPE_HOME,
                            );
                            if (locationData.isNotEmpty) {
                              bluetoothController.sendLocation(locationData);
                            }
                          }
                        : null,
                    icon: const Icon(Icons.home),
                    label: const Text('发送家'),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
