// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';

final logger = Logger.root;

FutureOr<T> runInDirectoryScope<T>({
  required String path,
  required FutureOr<T> Function() callback,
}) async {
  final original = Directory.current;
  Directory.current = Directory(path);
  final result = await callback();
  Directory.current = original;
  return result;
}

abstract class PlatformUtils {
  static String get prebuiltApplicationBinaryPath {
    assert(Platform.isLinux || Platform.isMacOS || Platform.isWindows);
    String path;
    if (Platform.isMacOS) {
      path = 'build/macos/Build/Products/Debug/preview_scaffold.app';
    } else if (Platform.isLinux) {
      // TODO(bkonyi): find path for debug binaries on Linux.
      throw UnimplementedError();
    } else if (Platform.isWindows) {
      // TODO(bkonyi): find path for debug binaries on Windows.
      throw UnimplementedError();
    } else {
      throw StateError('Unknown OS');
    }
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      logger.info(Directory.current.toString());
      throw StateError('Could not find prebuilt application binary at $path.');
    }
    return path;
  }

  static String getDeviceIdForPlatform() {
    assert(Platform.isLinux || Platform.isMacOS || Platform.isWindows);
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isWindows) return 'windows';
    throw StateError('Unknown OS');
  }
}

extension StringUtils on String {
  String get withNoTrailingNewLine => endsWith(Platform.lineTerminator)
      ? substring(0, length - Platform.lineTerminator.length)
      : this;

  String get asFilePath => Uri.file(this).toString();
}