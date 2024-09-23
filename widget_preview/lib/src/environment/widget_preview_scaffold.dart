// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// ignore: prefer_relative_imports, this won't be a relative import in the preview environment.
import 'package:widget_preview/src/environment/widget_preview.dart';

// ignore: uri_does_not_exist, will be generated.
import 'generated_preview.dart';

/// Custom [AssetBundle] used to map original asset paths from the parent
/// project to those in the preview project.
class PreviewAssetBundle extends PlatformAssetBundle {
  @override
  Future<ByteData> load(String key) {
    return super.load(key);
    // These assets are always present.
    if (key == 'AssetManifest.bin' ||
        key == 'AssetManifest.json' ||
        key == 'FontManifest.json') {
      return super.load(key);
    }
    // Other assets are from the parent project. Map their keys to those found
    // in the pubspec.yaml of the preview environment.
    return super.load('../../$key');
  }

  @override
  Future<ImmutableBuffer> loadBuffer(String key) async {
    return super.loadBuffer(key);
    return await ImmutableBuffer.fromAsset('../../$key');
  }
}

void main() {
  runApp(const WidgetPreviewScaffold());
}

class WidgetPreviewScaffold extends StatelessWidget {
  const WidgetPreviewScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    // ignore: undefined_method, will be present in generated_preview.dart.
    final previewList = previews();
    Widget previewView;
    if (previewList.isEmpty) {
      previewView = const Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Center(
            // TODO: consider including details on how to get started
            // with Widget Previews.
            child: Text(
              'No previews available',
              style: TextStyle(color: Colors.white),
            ),
          )
        ],
      );
    } else {
      previewView = LayoutBuilder(
        builder: (context, constraints) {
          return WidgetPreviewerWindowConstraints(
            constraints: constraints,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final preview in previewList) preview,
                ],
              ),
            ),
          );
        },
      );
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Material(
        color: Colors.transparent,
        child: DefaultAssetBundle(
          bundle: PreviewAssetBundle(),
          child: previewView,
        ),
      ),
    );
  }
}
