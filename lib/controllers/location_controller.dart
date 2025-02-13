import 'dart:typed_data';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

class LocationController extends GetxController {
  final Rx<LatLng?> currentLocation = Rx<LatLng?>(null);
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    checkPermissionAndGetLocation();
  }

  Future<void> checkPermissionAndGetLocation() async {
    try {
      // 检查定位服务是否开启
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Get.snackbar('错误', '请开启定位服务');
        return;
      }

      // 检查定位权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Get.snackbar('错误', '需要定位权限才能获取位置');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        Get.snackbar('错误', '定位权限被永久拒绝，请在设置中开启');
        return;
      }

      // 获取位置
      await getCurrentLocation();
    } catch (e) {
      Get.snackbar('错误', '检查权限时出错：$e');
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      isLoading.value = true;
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
      currentLocation.value = LatLng(position.latitude, position.longitude);
      print('当前位置: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      Get.snackbar('错误', '获取位置失败：$e');
      // 如果获取位置失败，设置一个默认位置（比如北京）
      currentLocation.value = const LatLng(39.9042, 116.4074);
    } finally {
      isLoading.value = false;
    }
  }

  // 位置数据类型
  static const int TYPE_CURRENT = 0x01;  // 当前位置
  static const int TYPE_HOME = 0x02;     // 家的位置

  // 家的位置
  final Rx<LatLng?> homeLocation = Rx<LatLng?>(null);

  // 设置家的位置
  void setHomeLocation(LatLng location) {
    homeLocation.value = location;
  }

  // 将位置数据转换为二进制字节数组
  List<int> locationToBytes({double? latitude, double? longitude, int type = TYPE_CURRENT}) {
    if (latitude == null || longitude == null) {
      if (currentLocation.value == null) return [];
      latitude = currentLocation.value!.latitude;
      longitude = currentLocation.value!.longitude;
    }
    
    // 将经纬度转换为二进制格式
    // 格式：
    // - 帧头: 0xAA 0x55 (2字节)
    // - 类型: 1字节 (0x01:当前位置, 0x02:家, 0x03:模拟位置)
    // - 纬度: IEEE-754浮点数 (4字节)
    // - 经度: IEEE-754浮点数 (4字节)
    // - 校验和: 所有字节的异或值 (1字节)
    List<int> bytes = [];
    
    // 帧头
    bytes.addAll([0xAA, 0x55]);
    
    // 类型
    bytes.add(type);
    
    // 纬度
    bytes.addAll(_doubleToBytes(latitude));
    
    // 经度
    bytes.addAll(_doubleToBytes(longitude));
    
    // 计算校验和
    int checksum = 0;
    for (var byte in bytes) {
      checksum ^= byte;
    }
    bytes.add(checksum);
    
    return bytes;
  }

  // 将double转换为4字节IEEE-754格式
  List<int> _doubleToBytes(double value) {
    // 创建一个ByteData对象来存储浮点数
    final bytes = ByteData(4);
    // 将double写入为32位浮点数
    bytes.setFloat32(0, value, Endian.little);
    // 返回字节列表
    return bytes.buffer.asUint8List().toList();
  }
}
