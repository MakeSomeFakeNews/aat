// 这个文件仅用于条件导入，实际使用的是 flutter_blue_plus
// 确保与 web_bluetooth.dart 中的类名保持一致，以便条件导入

class WebBluetooth {
  static bool isSupported() {
    return false;  // 移动端不使用 Web Bluetooth API
  }
}
