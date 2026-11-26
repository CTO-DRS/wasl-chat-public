import 'dart:math' as math;
import 'dart:typed_data';

/// BlurHash نقي بلغة Dart (2.5.0 — ج4) — تنفيذ محلي صغير للخوارزمية
/// المفتوحة (https://blurha.sh) بلا أي تبعية: سلسلة قصيرة (~20-30 حرفاً)
/// تصف ألوان الصورة المنخفضة التردد، تُخزّن داخل ميتا الرسالة (المشفّرة
/// مع الرسالة في المحادثات المشفرة) وتُفك عند الاستقبال إلى معاينة ضبابية
/// فورية قبل وصول الصورة نفسها.
abstract final class BlurHash {
  static const _chars =
      '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#\$%*+,-.:;=?@[]^_{|}~';

  /// هل السلسلة BlurHash صالح البنية؟ (الطول يطابق عدد المكوّنات)
  static bool isValid(String? hash) {
    if (hash == null || hash.length < 6) return false;
    for (final c in hash.codeUnits) {
      if (!_chars.codeUnits.contains(c)) return false;
    }
    final size = _decode83(hash, 0, 1);
    final nx = (size % 9) + 1, ny = (size ~/ 9) + 1;
    return hash.length == 4 + 2 * nx * ny;
  }

  /// ترميز بكسلات RGBA (عرض × ارتفاع × 4) إلى BlurHash
  static String encode(Uint8List rgba, int width, int height,
      {int componentsX = 4, int componentsY = 3}) {
    if (componentsX < 1 || componentsX > 9 || componentsY < 1 || componentsY > 9) {
      throw ArgumentError('components must be 1..9');
    }
    if (rgba.length < width * height * 4) throw ArgumentError('rgba too short');
    // تحويل مسبق إلى الخطي لكل بكسل مرة واحدة
    final lin = Float64List(width * height * 3);
    for (var i = 0, p = 0; i < width * height; i++, p += 4) {
      lin[i * 3] = _sToL(rgba[p]);
      lin[i * 3 + 1] = _sToL(rgba[p + 1]);
      lin[i * 3 + 2] = _sToL(rgba[p + 2]);
    }
    final factors = <List<double>>[];
    for (var j = 0; j < componentsY; j++) {
      for (var i = 0; i < componentsX; i++) {
        final norm = (i == 0 && j == 0) ? 1.0 : 2.0;
        var r = 0.0, g = 0.0, b = 0.0;
        for (var y = 0; y < height; y++) {
          final by = math.cos(math.pi * j * y / height);
          for (var x = 0; x < width; x++) {
            final basis = by * math.cos(math.pi * i * x / width);
            final k = (y * width + x) * 3;
            r += basis * lin[k];
            g += basis * lin[k + 1];
            b += basis * lin[k + 2];
          }
        }
        final scale = norm / (width * height);
        factors.add([r * scale, g * scale, b * scale]);
      }
    }
    final dc = factors.first;
    final ac = factors.sublist(1);
    final sb = StringBuffer();
    sb.write(_encode83((componentsX - 1) + (componentsY - 1) * 9, 1));
    double maxValue;
    if (ac.isNotEmpty) {
      var actualMax = 0.0;
      for (final f in ac) {
        for (final v in f) {
          actualMax = math.max(actualMax, v.abs());
        }
      }
      final q = (actualMax * 166 - 0.5).floor().clamp(0, 82);
      maxValue = (q + 1) / 166;
      sb.write(_encode83(q, 1));
    } else {
      maxValue = 1;
      sb.write(_encode83(0, 1));
    }
    sb.write(_encode83((_lToS(dc[0]) << 16) + (_lToS(dc[1]) << 8) + _lToS(dc[2]), 4));
    for (final f in ac) {
      int qz(double v) => (_signPow(v / maxValue, 0.5) * 9 + 9.5).floor().clamp(0, 18);
      sb.write(_encode83(qz(f[0]) * 19 * 19 + qz(f[1]) * 19 + qz(f[2]), 2));
    }
    return sb.toString();
  }

  /// فك BlurHash إلى بكسلات RGBA بالحجم المطلوب (صغير: 32×32 يكفي)
  static Uint8List decode(String hash, int width, int height, {double punch = 1}) {
    if (!isValid(hash)) throw ArgumentError('invalid blurhash');
    final size = _decode83(hash, 0, 1);
    final nx = (size % 9) + 1, ny = (size ~/ 9) + 1;
    final maxValue = (_decode83(hash, 1, 2) + 1) / 166 * punch;
    final colors = List<List<double>>.filled(nx * ny, const [0, 0, 0]);
    final dc = _decode83(hash, 2, 6);
    colors[0] = [_sToL(dc >> 16), _sToL((dc >> 8) & 255), _sToL(dc & 255)];
    for (var i = 1; i < nx * ny; i++) {
      final v = _decode83(hash, 4 + i * 2, 6 + i * 2);
      colors[i] = [
        _signPow(((v ~/ (19 * 19)) - 9) / 9, 2) * maxValue,
        _signPow((((v ~/ 19) % 19) - 9) / 9, 2) * maxValue,
        _signPow(((v % 19) - 9) / 9, 2) * maxValue,
      ];
    }
    final out = Uint8List(width * height * 4);
    // جداول جيب التمام مسبقة الحساب
    final cx = Float64List(width * nx);
    for (var x = 0; x < width; x++) {
      for (var i = 0; i < nx; i++) {
        cx[x * nx + i] = math.cos(math.pi * x * i / width);
      }
    }
    final cy = Float64List(height * ny);
    for (var y = 0; y < height; y++) {
      for (var j = 0; j < ny; j++) {
        cy[y * ny + j] = math.cos(math.pi * y * j / height);
      }
    }
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        var r = 0.0, g = 0.0, b = 0.0;
        for (var j = 0; j < ny; j++) {
          for (var i = 0; i < nx; i++) {
            final basis = cx[x * nx + i] * cy[y * ny + j];
            final c = colors[i + j * nx];
            r += c[0] * basis;
            g += c[1] * basis;
            b += c[2] * basis;
          }
        }
        final p = (y * width + x) * 4;
        out[p] = _lToS(r);
        out[p + 1] = _lToS(g);
        out[p + 2] = _lToS(b);
        out[p + 3] = 255;
      }
    }
    return out;
  }

  /// متوسط لون الصورة من الـ DC (لون أساس فوري قبل فك كامل)
  static (int r, int g, int b)? averageColor(String? hash) {
    if (!isValid(hash)) return null;
    final dc = _decode83(hash!, 2, 6);
    return (dc >> 16, (dc >> 8) & 255, dc & 255);
  }

  /// ملف BMP 32-بت من بكسلات RGBA — يفكه Flutter على كل المنصات (ويب وجوال)
  /// فيُعرض بـ Image.memory بلا تحويل غير متزامن
  static Uint8List rgbaToBmp(Uint8List rgba, int width, int height) {
    const header = 14 + 40;
    final rowBytes = width * 4;
    final fileSize = header + rowBytes * height;
    final b = ByteData(fileSize);
    b.setUint8(0, 0x42); // B
    b.setUint8(1, 0x4D); // M
    b.setUint32(2, fileSize, Endian.little);
    b.setUint32(10, header, Endian.little);
    b.setUint32(14, 40, Endian.little); // BITMAPINFOHEADER
    b.setInt32(18, width, Endian.little);
    b.setInt32(22, -height, Endian.little); // سالب = من الأعلى للأسفل
    b.setUint16(26, 1, Endian.little);
    b.setUint16(28, 32, Endian.little);
    b.setUint32(30, 0, Endian.little); // BI_RGB
    b.setUint32(34, rowBytes * height, Endian.little);
    var o = header;
    for (var p = 0; p < width * height * 4; p += 4) {
      b.setUint8(o++, rgba[p + 2]); // B
      b.setUint8(o++, rgba[p + 1]); // G
      b.setUint8(o++, rgba[p]); // R
      b.setUint8(o++, 255);
    }
    return b.buffer.asUint8List();
  }

  // ---------- أدوات ----------

  static String _encode83(int value, int length) {
    final sb = StringBuffer();
    for (var i = 1; i <= length; i++) {
      final digit = (value ~/ math.pow(83, length - i).toInt()) % 83;
      sb.write(_chars[digit]);
    }
    return sb.toString();
  }

  static int _decode83(String s, int from, int to) {
    var v = 0;
    for (var i = from; i < to; i++) {
      v = v * 83 + _chars.indexOf(s[i]);
    }
    return v;
  }

  static double _sToL(int v) {
    final x = v / 255;
    return x <= 0.04045 ? x / 12.92 : math.pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  static int _lToS(double v) {
    final x = v.clamp(0.0, 1.0);
    return x <= 0.0031308
        ? (x * 12.92 * 255 + 0.5).floor()
        : ((1.055 * math.pow(x, 1 / 2.4) - 0.055) * 255 + 0.5).floor();
  }

  static double _signPow(double v, double e) =>
      (v < 0 ? -1 : 1) * math.pow(v.abs(), e).toDouble();
}
