// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:developer';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:widget_preview/src/tool/widget_preview_environment.dart';

final logger = Logger.root
  ..onRecord.listen((record) {
    // ignore: avoid_print
    print('[${record.level}]: ${record.message}');
    log(
      record.message,
      time: record.time,
      sequenceNumber: record.sequenceNumber,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });

Future<void> main(List<String> args) async {
  logger.level = Level.ALL;

  var projectRoot = Directory.current;
  if (args.isNotEmpty) {
    var arg = args.first;
    // TODO(bkonyi): assert arg is a directory.
    projectRoot = Directory(arg);
  }

  final environment = WidgetPreviewEnvironment();
  await environment.start(projectRoot);
}
