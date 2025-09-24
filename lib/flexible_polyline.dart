import 'dart:math' as math;

class GeoCoordinates {
  final double lat;
  final double lng;
  final double? thirdDim;

  GeoCoordinates(this.lat, this.lng, [this.thirdDim]);

  @override
  String toString() => 'GeoCoordinates(lat: $lat, lng: $lng, thirdDim: $thirdDim)';
}

class FlexiblePolyline {
  static List<GeoCoordinates> decode(String encoded) {
    int index = 0;

    int result = 0;
    int shift = 0;
    int byte;

    // Decode header
    do {
      byte = _decodeChar(encoded.codeUnitAt(index++));
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    final precision = result & 0x0F;
    final thirdDimFlag = (result >> 4) & 0x07;
    final thirdDimPrecision = (result >> 7) & 0x0F;

    final factorDegree = math.pow(10, precision).toDouble();
    final factorZ = math.pow(10, thirdDimPrecision).toDouble();

    int lastLat = 0;
    int lastLng = 0;
    int lastZ = 0;

    List<GeoCoordinates> coordinates = [];

    while (index < encoded.length) {
      final lat = _decodeSignedValue(encoded, index, outIndex: (v) => index = v);
      final lng = _decodeSignedValue(encoded, index, outIndex: (v) => index = v);

      lastLat += lat;
      lastLng += lng;

      double? thirdDim;
      if (thirdDimFlag != 0) {
        final z = _decodeSignedValue(encoded, index, outIndex: (v) => index = v);
        lastZ += z;
        thirdDim = lastZ / factorZ;
      }

      coordinates.add(
        GeoCoordinates(
          lastLat / factorDegree,
          lastLng / factorDegree,
          thirdDim,
        ),
      );
    }

    return coordinates;
  }

  static int _decodeChar(int charCode) => charCode - 63;

  static int _decodeUnsignedValue(String encoded, int index, {required void Function(int) outIndex}) {
    int result = 0;
    int shift = 0;
    int byte;

    do {
      byte = _decodeChar(encoded.codeUnitAt(index++));
      result |= (byte & 0x1F) << shift;
      shift += 5;
    } while (byte >= 0x20);

    outIndex(index);
    return result;
  }

  static int _decodeSignedValue(String encoded, int index, {required void Function(int) outIndex}) {
    final value = _decodeUnsignedValue(encoded, index, outIndex: outIndex);
    return (value & 1) != 0 ? ~(value >> 1) : value >> 1;
  }
}
