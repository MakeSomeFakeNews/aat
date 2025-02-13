class TianDiTuConfig {
  static const String token = '7b6c4639d43c1623aadf28127d053d88';
  
  // 影像底图
  static const String imgBase = 'tianditu.gov.cn/img_w/wmts';
  // 影像注记
  static const String ciaBase = 'tianditu.gov.cn/cia_w/wmts';
  
  static const List<String> subdomains = [
    't0', 't1', 't2', 't3', 't4', 't5', 't6', 't7'
  ];

  static String getTileUrl(String baseUrl, int z, int x, int y) {
    return 'https://${subdomains[x % subdomains.length]}.$baseUrl'
        '?SERVICE=WMTS'
        '&REQUEST=GetTile'
        '&VERSION=1.0.0'
        '&LAYER=img'
        '&STYLE=default'
        '&TILEMATRIXSET=w'
        '&FORMAT=tiles'
        '&TILEMATRIX=$z'
        '&TILEROW=$y'
        '&TILECOL=$x'
        '&tk=$token';
  }

  static String getImgUrl(int z, int x, int y) {
    return getTileUrl(imgBase, z, x, y);
  }

  static String getCiaUrl(int z, int x, int y) {
    return getTileUrl(ciaBase, z, x, y);
  }
}
