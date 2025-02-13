import 'dart:async';
import 'dart:js' as js;
import 'dart:js_util';

// Web Bluetooth API 的类型定义
class JSBluetoothDevice {
  final String id;
  final String name;
  final dynamic gatt;
  
  JSBluetoothDevice(this.id, this.name, this.gatt);
}

class WebBluetoothDevice {
  final String id;
  final String name;
  final JSBluetoothDevice nativeDevice;

  WebBluetoothDevice(this.id, this.name, this.nativeDevice);
}

class WebBluetooth {
  Future<List<WebBluetoothDevice>> startScan() async {
    try {
      // 请求蓝牙设备
      final options = js.JsObject.jsify({
        'filters': [
          {'services': ['battery_service']},  // 可以根据需要修改服务UUID
        ],
        'optionalServices': ['generic_access']
      });

      final dynamic rawDevice = await promiseToFuture(
        js.context['navigator']['bluetooth'].callMethod('requestDevice', [options])
      );

      if (rawDevice != null) {
        final device = JSBluetoothDevice(
          getProperty(rawDevice, 'id'),
          getProperty(rawDevice, 'name') ?? 'Unknown Device',
          getProperty(rawDevice, 'gatt')
        );

        return [
          WebBluetoothDevice(
            device.id,
            device.name,
            device,
          )
        ];
      }
      
      return [];
    } catch (e) {
      print('Web Bluetooth Error: $e');
      return [];
    }
  }

  Future<bool> connect(WebBluetoothDevice device) async {
    try {
      if (device.nativeDevice.gatt == null) return false;
      
      final gatt = await promiseToFuture(
        callMethod(device.nativeDevice.gatt, 'connect', [])
      );
      return gatt != null;
    } catch (e) {
      print('Connection error: $e');
      return false;
    }
  }

  Future<void> disconnect(WebBluetoothDevice device) async {
    try {
      if (device.nativeDevice.gatt != null) {
        callMethod(device.nativeDevice.gatt, 'disconnect', []);
      }
    } catch (e) {
      print('Disconnection error: $e');
    }
  }

  bool isSupported() {
    return js.context['navigator']['bluetooth'] != null;
  }
}
