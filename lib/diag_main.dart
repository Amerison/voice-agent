// TEMPORARY diagnostic entrypoint. Delete after debugging.
import 'dart:io';

import 'package:flutter/foundation.dart';
// ignore: depend_on_referenced_packages
import 'package:logging/logging.dart';

import 'main.dart' as app;

final _file = File('${Directory.systemTemp.path}/diag.log');

void _write(String line) {
  _file.writeAsStringSync(
    '${DateTime.now().toIso8601String()} $line\n',
    mode: FileMode.append,
    flush: true,
  );
}

void main() {
  _write('---- launch');
  debugPrint = (message, {wrapWidth}) => _write(message ?? '');
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((r) {
    _write('[${r.loggerName}] ${r.level.name} ${r.message} ${r.error ?? ''}');
  });
  app.main();
}
