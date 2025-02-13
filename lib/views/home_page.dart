import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/bluetooth_controller.dart';
import '../widgets/bluetooth_dialog.dart';
import 'map_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final BluetoothController controller = Get.put(BluetoothController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('AAT Bluetooth'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.bluetooth_searching),
            onPressed: () => _showBluetoothDialog(context, controller),
          ),
          Obx(() => controller.connectedDevice.value != null
            ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => controller.disconnectDevice(),
              )
            : const SizedBox.shrink()),
        ],
      ),
      body: MapView(),
    );
  }

  void _showBluetoothDialog(BuildContext context, BluetoothController controller) {
    showDialog(
      context: context,
      builder: (context) => BluetoothDialog(controller: controller),
    );
  }
}
