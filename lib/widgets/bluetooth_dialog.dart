import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../controllers/bluetooth_controller.dart';

class BluetoothDialog extends StatefulWidget {
  final BluetoothController controller;

  const BluetoothDialog({
    super.key,
    required this.controller,
  });

  @override
  State<BluetoothDialog> createState() => _BluetoothDialogState();
}

class _BluetoothDialogState extends State<BluetoothDialog> {
  Timer? _timer;
  int _remainingSeconds = BluetoothController.scanDurationSeconds;
  Worker? _scanningWorker;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _startTimer();

    // 监听扫描状态变化
    _scanningWorker = ever(widget.controller.isScanning, (bool isScanning) {
      if (!_mounted) return;
      if (isScanning) {
        _startTimer();
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _mounted = false;
    _timer?.cancel();
    _scanningWorker?.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (!_mounted) return;
    _timer?.cancel();
    _remainingSeconds = BluetoothController.scanDurationSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _timer?.cancel();
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('选择蓝牙设备'),
              Obx(() => IconButton(
                    icon: Icon(
                      widget.controller.isScanning.value
                          ? Icons.stop
                          : Icons.refresh,
                      color: Colors.blue,
                    ),
                    onPressed: () {
                      widget.controller.toggleScan();
                      if (!widget.controller.isScanning.value) {
                        _timer?.cancel();
                      }
                    },
                  )),
            ],
          ),
          Obx(() => widget.controller.isScanning.value
              ? Text(
                  '扫描中 ($_remainingSeconds秒)',
                  style: const TextStyle(fontSize: 12),
                )
              : const SizedBox.shrink()),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 300, // 固定高度，避免设备过多时对话框过长
        child: Obx(
          () => widget.controller.devices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      widget.controller.isScanning.value
                          ? const CircularProgressIndicator()
                          : const Icon(
                              Icons.bluetooth_disabled,
                              size: 48,
                              color: Colors.grey,
                            ),
                      const SizedBox(height: 16),
                      Text(
                        widget.controller.isScanning.value
                            ? '正在搜索设备...'
                            : '未发现设备',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: widget.controller.devices.length,
                  itemBuilder: (context, index) {
                    final device = widget.controller.devices[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.bluetooth),
                        title: Text(device.name),
                        subtitle: Text(
                          device.id.id,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: StreamBuilder<BluetoothConnectionState>(
                          stream: device.connectionState,
                          initialData: BluetoothConnectionState.disconnected,
                          builder: (c, snapshot) {
                            if (snapshot.data ==
                                BluetoothConnectionState.connected) {
                              return const Icon(
                                Icons.bluetooth_connected,
                                color: Colors.green,
                              );
                            }
                            return Obx(() {
                              // 如果该设备正在连接
                              if (widget.controller.isConnecting.value &&
                                  widget.controller.connectingDevice.value?.id == device.id) {
                                return const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              bool hasConnectedDevice = widget.controller.connectedDevice.value != null;
                              bool isThisDeviceConnected = widget.controller.connectedDevice.value?.id == device.id;
                              
                              // 如果已经有设备连接且不是当前设备，显示禁用状态的按钮
                              if (hasConnectedDevice && !isThisDeviceConnected) {
                                return ElevatedButton(
                                  onPressed: null,
                                  child: const Text('请先断开'),
                                );
                              }

                              return ElevatedButton(
                                onPressed: widget.controller.isConnecting.value
                                    ? null // 如果正在连接其他设备，禁用按钮
                                    : () {
                                        widget.controller.connectToDevice(device);
                                        // 只有连接成功后才关闭对话框
                                        if (widget.controller.connectedDevice.value?.id == device.id) {
                                          Get.back();
                                        }
                                      },
                                child: const Text('连接'),
                              );
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            if (widget.controller.isScanning.value) {
              widget.controller.toggleScan();
            }
            Get.back();
          },
          child: const Text('取消'),
        ),
      ],
    );
  }
}
