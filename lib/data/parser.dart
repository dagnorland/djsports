class Parser {
  static int getInt(Map<String, dynamic> obj, String key) {
    if (!obj.containsKey(key)) {
      return 0;
    }
    var res = obj[key];
    if (res is int) {
      return res;
    }
    if (res is double) {
      return res.toInt();
    }
    if (res is String) {
      return int.tryParse(res) ?? 0;
    }
    return 0;
  }

  static double getDouble(Map<String, dynamic> obj, String key) {
    if (!obj.containsKey(key)) {
      return 0;
    }
    var res = obj[key];
    if (res is double) {
      return res;
    }
    if (res is int) {
      return res.toDouble();
    }
    if (res is String) {
      return double.tryParse(res) ?? 0;
    }
    return 0;
  }

  static double getDoubleWithKeys(Map<String, dynamic> obj, List<String> keys) {
    for (var key in keys) {
      var d = getDouble(obj, key);

      return d;
    }
    return 0;
  }

  static int getIntWithKeys(Map<String, dynamic> obj, List<String> keys) {
    for (var key in keys) {
      var d = getInt(obj, key);
      return d;
    }
    return 0;
  }

  static String getStringWithKeys(Map<String, dynamic> obj, List<String> keys) {
    for (var key in keys) {
      var d = getString(obj, key);
      return d;
    }
    return '';
  }

  static bool getBool(Map<String, dynamic> obj, String key) {
    if (!obj.containsKey(key)) {
      return false;
    }
    var res = obj[key];
    if (res is bool) {
      return res;
    }
    return false;
  }

  static String getString(Map<String, dynamic> obj, String key) {
    if (!obj.containsKey(key)) {
      return '';
    }
    var res = obj[key];
    if (res is String) {
      return res;
    }
    if (res is num) {
      return res.toString();
    }
    return '';
  }

  static DateTime getTime(Map<String, dynamic> obj, String key) {
    if (!obj.containsKey(key)) {
      return DateTime.now();
    }
    var res = obj[key];
    if (res is num) {
      return DateTime.fromMillisecondsSinceEpoch(res.toInt() * 1000);
    }
    if (res is String) {
      return DateTime.tryParse(res) ?? DateTime.now();
    }
    return DateTime.now();
  }
}
