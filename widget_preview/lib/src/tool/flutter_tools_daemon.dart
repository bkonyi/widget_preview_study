// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';

import 'utils.dart';

final logger = Logger.root;

class FlutterToolsDaemonRequest {
  FlutterToolsDaemonRequest({required this.method, this.params});

  factory FlutterToolsDaemonRequest.hotRestart({required String appId}) =>
      FlutterToolsDaemonRequest._reloadOrRestart(
        appId: appId,
        restart: true,
      );

  factory FlutterToolsDaemonRequest.hotReload({required String appId}) =>
      FlutterToolsDaemonRequest._reloadOrRestart(
        appId: appId,
        restart: false,
      );

  factory FlutterToolsDaemonRequest._reloadOrRestart({
    required String appId,
    required bool restart,
  }) {
    return FlutterToolsDaemonRequest(
      method: 'app.restart',
      params: {
        'appId': appId,
        'fullRestart': restart,
        'pause': false,
        'reason': 'File changed',
        'debounce': true,
      },
    );
  }

  String encode() => _encoded ??= json.encode(
        [
          {
            'id': '${_id++}',
            'method': method,
            if (params != null) 'params': params,
          }
        ],
      );

  final String method;
  final Map<String, Object?>? params;

  String? _encoded;

  static int _id = 0;
}

/// Handler for daemon events from Flutter Tools.
class FlutterToolsDaemon {
  FlutterToolsDaemon({
    required this.process,
    required this.onAppStart,
  }) {
    stdoutSub = process.stdout.transform(utf8.decoder).listen((e) {
      logger.info('[STDOUT] ${e.withNoTrailingNewLine}');
      _handleEvent(e);
    });

    stderrSub = process.stderr.transform(utf8.decoder).listen((e) {
      if (e == '\n') return;
      logger.info('[STDERR] ${e.withNoTrailingNewLine}');
    });
  }

  /// The Flutter Tools process.
  final Process process;

  /// Invoked when the 'app.started' event is sent by the daemon.
  void Function(String) onAppStart;

  /// The application ID associated with the running application.
  String? appId;

  late final StreamSubscription<String> stdoutSub;
  late final StreamSubscription<String> stderrSub;

  Future<void> shutdown() async {
    process.kill();
    await Future.wait([
      stdoutSub.cancel(),
      stderrSub.cancel(),
    ]);
  }

  /// Trigger a hot reload in the target process.
  void hotReload() {
    process.stdin.writeln(
      FlutterToolsDaemonRequest.hotReload(appId: appId!).encode(),
    );
  }

  /// Trigger a hot restart in the target process.
  void hotRestart() {
    process.stdin.writeln(
      FlutterToolsDaemonRequest.hotRestart(appId: appId!).encode(),
    );
  }

  void _handleEvent(String event) {
    List<Object?> root;
    try {
      root = json.decode(event) as List<Object?>;
    } on FormatException {
      return;
    }
    final data = root.first as Map<String, Object?>;
    if (data
        case {
          'event': 'app.started',
          'params': {
            'appId': String id,
          }
        } when appId == null) {
      appId = id;
      onAppStart(id);
    }
  }
}
