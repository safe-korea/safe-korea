import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class FixtureTiles extends TileProvider {
  FixtureTiles(this.fail);
  final bool fail;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    if (fail) return MemoryImage(Uint8List(0));
    return MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      ),
    );
  }
}
