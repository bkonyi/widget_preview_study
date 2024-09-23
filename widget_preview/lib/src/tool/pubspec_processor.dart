// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

import 'constants.dart';
import 'utils.dart';

final logger = Logger.root;

/// Handles adding package dependencies, assets, and fonts to the preview
/// scaffolding project's Pubspec.
// TODO(bkonyi): Check for new assets and fonts after first run.
class PubspecProcessor {
  PubspecProcessor({required this.projectRoot});

  /// The root of the parent project.
  final Directory projectRoot;

  static const _kPubspecYaml = 'pubspec.yaml';

  // Pubspec keys.
  static const _kName = 'name';
  static const _kFlutter = 'flutter';
  static const _kAssets = 'assets';
  static const _kAsset = 'asset';
  static const _kFonts = 'fonts';
  static const _kFontFamily = 'family';
  static const _kFontWeight = 'weight';
  static const _kFontStyle = 'style';

  Future<String> _populateAssetsAndFonts() async {
    final parentPubspec = File(path.join(projectRoot.path, _kPubspecYaml));
    if (!await parentPubspec.exists()) {
      // TODO(bkonyi): throw a better error.
      throw StateError('Could not find pubspec.yaml');
    }

    // Read the asset and font information from the parent project's pubspec,
    // updating paths so the relative paths will point to the original assets
    // from the preview project.
    final pubspecContents = await parentPubspec.readAsString();
    final yaml = loadYamlDocument(pubspecContents).contents.value as YamlMap;
    final projectName = yaml[_kName] as String;
    final flutterYaml = yaml[_kFlutter] as YamlMap;
    final assets = (flutterYaml[_kAssets] as YamlList)
        .value
        .cast<String>()
        // Reference the assets from the parent project.
        .map((e) => '${e.replaceAll('\\', '/')}')
        .toList();
    print(Directory.current);
    for (final asset in assets) {
      final dir =
          Directory(path.dirname(path.join(previewScaffoldProjectPath, asset)));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      File('${projectRoot.path}/$asset')
          .copySync(path.join(previewScaffoldProjectPath, asset));
    }
    final fontsYaml = (flutterYaml[_kFonts] as YamlList).value.cast<YamlMap>();
    for (final family in fontsYaml) {
      for (final font in family[_kFonts] as YamlList) {
          final asset = font[_kAsset] as String;
          final dir = Directory(
              path.dirname(path.join(previewScaffoldProjectPath, asset)));
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          File('${projectRoot.path}/$asset')
              .copySync(path.join(previewScaffoldProjectPath, asset));
      }
    }

    final fonts = <Map<String, Object>>[
      for (final familyYaml in fontsYaml)
        <String, Object>{
          _kFontFamily: familyYaml[_kFontFamily] as String,
          _kFonts: <Map<String, Object>>[
            for (final fontsYaml in familyYaml[_kFonts] as YamlList)
              <String, Object>{
                // Reference the assets from the parent project.
                _kAsset:
                    '${(fontsYaml as YamlMap)[_kAsset].replaceAll('\\', '/')}',
                if (fontsYaml.containsKey(_kFontWeight))
                  _kFontWeight: fontsYaml[_kFontWeight] as int,
                if (fontsYaml.containsKey(_kFontStyle))
                  _kFontStyle: fontsYaml[_kFontStyle] as String,
              }
          ]
        }
    ];

    // Write the asset and font information to the preview scaffold's pubspec.
    final previewEnvironmentPubspec = File(
      path.join(previewScaffoldProjectPath, _kPubspecYaml),
    );
    final editor = YamlEditor(await previewEnvironmentPubspec.readAsString());

    if (assets.isNotEmpty) {
      logger.info(
        'Added assets from the parent project to $previewEnvironmentPubspec.',
      );
      editor.update([_kFlutter, _kAssets], assets);
    }

    if (fonts.isNotEmpty) {
      logger.info(
        'Added fonts from the parent project to $previewEnvironmentPubspec.',
      );
      editor.update([_kFlutter, _kFonts], fonts);
    }

    await previewEnvironmentPubspec.writeAsString(editor.toString());

    // TODO(bkonyi): don't return this.
    return projectName;
  }

  /// Initializes the pubspec.yaml for the preview scaffolding project.
  ///
  /// This adds dependencies on package:widget_preview and the parent project,
  /// while also populating the initial set of assets and fonts.
  Future<void> initialize() async {
    final projectName = await _populateAssetsAndFonts();

    logger.info(
      'Adding package:widget_preview and $projectName '
      'dependency...',
    );

    final widgetPreviewPath = path
        .relative(
          path.dirname(
            path.dirname(
              Platform.script.toFilePath(),
            ),
          ),
        )
        .replaceAll('\\', '/');

    final args = [
      'pub',
      'add',
      '--directory=.dart_tool/preview_scaffold',
      // TODO(bkonyi): add dependency on published package:widget_preview or
      // remove this if it's shipped with package:flutter
      'widget_preview:{"path":"$widgetPreviewPath"}',
      '$projectName:{"path":"${path.relative(projectRoot.path).replaceAll('\\', '/')}"}',
    ];

    checkExitCode(
      description: 'Adding pub dependencies',
      failureMessage: 'Failed to add dependencies to pubspec.yaml!',
      result: await Process.run(PlatformUtils.flutter, args),
    );
  }
}
