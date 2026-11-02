import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  await Directory('artifacts/visual-qa').create(recursive: true);
  await integrationDriver(
    onScreenshot: (name, bytes, [args]) async {
      await File('artifacts/visual-qa/$name.png').writeAsBytes(bytes);
      return true;
    },
  );
}
