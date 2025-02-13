import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BluetoothController extends GetxController {
  Map<String, BluetoothCharacteristic> _writeCharacteristics = {};
  final devices = <BluetoothDevice>[].obs;
  final isScanning = false.obs;
  final isConnecting = false.obs;
  final Rx<BluetoothDevice?> connectedDevice = Rx<BluetoothDevice?>(null);
  final Rx<BluetoothDevice?> connectingDevice = Rx<BluetoothDevice?>(null);

  // 配置参数
  static const int scanDurationSeconds = 10;
  static const int connectTimeoutSeconds = 10;

  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionStateSubscription;

  @override
  void onInit() {
    super.onInit();
    _initBluetooth();
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.onClose();
  }

  void _initBluetooth() {
    // Web平台不自动扫描，需要用户手动点击按钮触发
    if (!GetPlatform.isWeb) {
      toggleScan();
    }
  }

  Future<void> toggleScan() async {
    try {
      if (isScanning.value) {
        await FlutterBluePlus.stopScan();
        isScanning.value = false;
        _scanSubscription?.cancel();
      } else {
        // Clear the previous devices
        devices.clear();

        // Start scanning
        await FlutterBluePlus.startScan(
            timeout: const Duration(seconds: scanDurationSeconds));
        isScanning.value = true;

        // Listen to scan results
        _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
          // 过滤掉未知设备，只保留有名称的设备
          final validDevices = results
              .where((r) => r.device.name.isNotEmpty)
              .map((r) => r.device);

          // 更新设备列表，避免重复
          for (var device in validDevices) {
            if (!devices.contains(device)) {
              devices.add(device);
            }
          }
        });

        // 设置扫描超时后自动停止
        Future.delayed(Duration(seconds: scanDurationSeconds), () {
          if (isScanning.value) {
            toggleScan();
          }
        });
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '扫描设备时出错：${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // 发送位置数据
  Future<void> sendLocation(List<int> locationData,
      {String? serviceUuid}) async {
    if (connectedDevice.value == null || _writeCharacteristics.isEmpty) {
      Get.snackbar(
        '错误',
        '没有连接的设备或未找到可写特征',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      BluetoothCharacteristic? characteristic;
      if (serviceUuid != null) {
        characteristic = _writeCharacteristics[serviceUuid];
        if (characteristic == null) {
          throw Exception('未找到指定服务的写特征：$serviceUuid');
        }
      } else {
        // 如果没有指定服务UUID，使用第一个可用的写特征
        characteristic = _writeCharacteristics.values.first;
      }

      await characteristic.write(locationData);
    } catch (e) {
      Get.snackbar(
        '错误',
        '发送位置失败：$e',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    // 如果已经有设备连接，需要先断开
    if (connectedDevice.value != null) {
      Get.snackbar(
        '提示',
        '请先断开当前设备的连接',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    // 如果正在连接其他设备，直接返回
    if (isConnecting.value) {
      Get.snackbar(
        '提示',
        '正在连接其他设备，请稍后再试',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    try {
      // 如果正在扫描，停止扫描
      if (isScanning.value) {
        await FlutterBluePlus.stopScan();
        isScanning.value = false;
      }

      isConnecting.value = true;
      connectingDevice.value = device;

      // 添加连接超时
      await device
          .connect(
        timeout: Duration(seconds: connectTimeoutSeconds),
      )
          .timeout(
        Duration(seconds: connectTimeoutSeconds),
        onTimeout: () {
          throw TimeoutException('连接超时');
        },
      );

      // 获取所有服务
      final services = await device.discoverServices();

      _writeCharacteristics.clear();
      // 查找所有写特征
      for (final service in services) {
        for (final characteristic in service.characteristics) {
          if (characteristic.properties.write) {
            _writeCharacteristics[service.uuid.toString()] = characteristic;
          }
        }
      }

      if (_writeCharacteristics.isEmpty) {
        throw Exception('未找到可写特征');
      }

      // 监听连接状态
      _connectionStateSubscription?.cancel();
      _connectionStateSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          // 设备断开连接
          _writeCharacteristics.clear();
          connectedDevice.value = null;
          Get.snackbar(
            '连接断开',
            '设备 ${device.name} 已断开连接',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
      });

      connectedDevice.value = device;
      Get.snackbar(
        '连接成功',
        '已连接到 ${device.name}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      String errorMessage = '连接失败';
      if (e is TimeoutException) {
        errorMessage = '连接超时';
      }
      Get.snackbar(
        '连接失败',
        '$errorMessage：${device.name}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      isConnecting.value = false;
      connectingDevice.value = null;
    }
  }

  Future<void> disconnectDevice() async {
    _connectionStateSubscription?.cancel();
    _writeCharacteristics.clear();
    try {
      if (connectedDevice.value != null) {
        await connectedDevice.value!.disconnect();
        connectedDevice.value = null;
        Get.snackbar(
          '断开连接',
          '设备已断开连接',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        '错误',
        '断开连接失败：${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}
