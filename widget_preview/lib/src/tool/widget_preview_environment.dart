// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:code_builder/code_builder.dart' as builder;
import 'package:dart_style/dart_style.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';

import 'constants.dart';
import 'flutter_tools_daemon.dart';
import 'pubspec_processor.dart';
import 'utils.dart';

/// Clears preview scaffolding state on each run.
///
/// Set to false for release.
const developmentMode = true;

const shouldUsePrebuiltBinaryVar = 'NO_USE_PREBUILT_BINARY';
const shouldUsePrebuiltBinary =
    !const bool.fromEnvironment(shouldUsePrebuiltBinaryVar);

final logger = Logger.root;

typedef PreviewMapping = Map<String, List<String>>;

class WidgetPreviewEnvironment {
  late final String _vmServiceInfoPath;
  final _pathToPreviews = PreviewMapping();
  PubspecProcessor? _pubspecProcessor;
  StreamSubscription<WatchEvent>? _fileWatcher;

  Future<void> start(Directory projectRoot) async {
    print(Platform.environment);
    _pubspecProcessor = PubspecProcessor(projectRoot: projectRoot);
    // TODO(bkonyi): consider parallelizing initializing the scaffolding
    // project and finding the previews.
    await _ensurePreviewScaffoldExists(projectRoot);
    _pathToPreviews.addAll(_findPreviewFunctions(projectRoot));
    await _populatePreviewsInScaffold(_pathToPreviews);
    await _runPreviewEnvironment();
    await _cleanup();
  }

  Future<void> _cleanup() async {
    await _fileWatcher?.cancel();
    _pubspecProcessor = null;
  }

  Future<void> _ensurePreviewScaffoldExists(Directory projectRoot) async {
    // TODO(bkonyi): check for .dart_tool explicitly
    if (developmentMode) {
      final previewScaffoldProject = Directory(previewScaffoldProjectPath);
      if (await previewScaffoldProject.exists()) {
        await previewScaffoldProject.delete(recursive: true);
      }
    }
    if (await Directory(previewScaffoldProjectPath).exists()) {
      logger.info('Preview scaffolding exists!');
      return;
    }

    logger.info('Creating $previewScaffoldProjectPath...');
    checkExitCode(
      description: 'Creating $previewScaffoldProjectPath',
      failureMessage:
          'Failed to create preview scaffold at $previewScaffoldProjectPath',
      result: await Process.run(PlatformUtils.flutter, [
        'create',
        '--platforms=windows,linux,macos',
        '.dart_tool/preview_scaffold',
      ]),
    );

    if (!(await Directory(previewScaffoldProjectPath).exists())) {
      logger.severe('Could not create $previewScaffoldProjectPath!');
      throw StateError('Could not create $previewScaffoldProjectPath.');
    }

    logger.info(Uri(path: previewScaffoldProjectPath).resolve('lib/main.dart'));
    logger.info('Writing preview scaffolding entry point...');

    // widget_preview_scaffold.dart contains the contents of main.dart for the
    // generated preview environment.
    await File.fromUri(
      Platform.script.resolve(
        '../lib/src/environment/widget_preview_scaffold.dart',
      ),
    ).copy(
      Uri(path: previewScaffoldProjectPath).resolve('lib/main.dart').toString(),
    );

    await _pubspecProcessor!.initialize();

    // Generate an empty 'lib/generated_preview.dart'
    logger.info(
      'Generating empty ${previewScaffoldProjectPath}lib/generated_preview.dart',
    );

    await _populatePreviewsInScaffold(const <String, List<String>>{});

    if (shouldUsePrebuiltBinary) {
      logger.info('Performing initial build...');
      await _initialBuild();
    } else {
      logger.warning(
        'Skipping build of prebuilt binary as $shouldUsePrebuiltBinaryVar is defined',
      );
    }

    logger.info('Preview scaffold initialization complete!');
  }

  Future<void> _initialBuild() async {
    await runInDirectoryScope(
      path: previewScaffoldProjectPath,
      callback: () async {
        assert(Platform.isLinux || Platform.isMacOS || Platform.isWindows);
        final args = <String>[
          'build',
          // This assumes the device ID string matches the subcommand name.
          PlatformUtils.getDeviceIdForPlatform(),
          '--device-id=${PlatformUtils.getDeviceIdForPlatform()}',
          '--debug',
        ];
        checkExitCode(
          description: 'Initial build',
          failureMessage: 'Failed to generate prebuilt preview scaffold!',
          result: await Process.run(PlatformUtils.flutter, args),
        );
      },
    );
  }

  /// Search for functions annotated with `@Preview` in the current project.
  PreviewMapping _findPreviewFunctions(FileSystemEntity entity) {
    final collection = AnalysisContextCollection(
      includedPaths: [entity.absolute.path],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
    );

    final previews = PreviewMapping();

    for (final context in collection.contexts) {
      logger.info('Finding previews in ${context.contextRoot.root.path} ...');

      for (final filePath in context.contextRoot.analyzedFiles()) {
        if (!filePath.endsWith('.dart')) {
          continue;
        }

        final lib = context.currentSession.getParsedLibrary(filePath);
        if (lib is ParsedLibraryResult) {
          for (final unit in lib.units) {
            final previewEntries =
                previews.putIfAbsent(unit.uri.toString(), () => <String>[]);
            for (final entity in unit.unit.childEntities) {
              if (entity is FunctionDeclaration &&
                  !entity.name.toString().startsWith('_')) {
                var foundPreview = false;
                for (final annotation in entity.metadata) {
                  if (annotation.name.name == 'Preview') {
                    // What happens if the annotation is applied multiple times?
                    foundPreview = true;
                    break;
                  }
                }
                if (foundPreview) {
                  logger.info('Found preview at:');
                  logger.info('File path: ${unit.uri}');
                  logger.info('Preview function: ${entity.name}');
                  logger.info('');
                  previewEntries.add(entity.name.toString());
                }
              }
            }
          }
        } else {
          logger.warning('Unknown library type at $filePath: $lib');
        }
      }
    }
    return previews;
  }

  Future<void> _populatePreviewsInScaffold(PreviewMapping previews) async {
    final lib = builder.Library(
      (b) => b.body.addAll(
        [
          builder.Directive.import(
            'package:widget_preview/widget_preview.dart',
          ),
          builder.Method(
            (b) => b
              ..body = builder.literalList(
                [
                  for (final MapEntry(
                        key: String path,
                        value: List<String> previewMethods
                      ) in previews.entries) ...[
                    for (final method in previewMethods)
                      builder.refer(method, path).spread.call([]),
                  ],
                ],
              ).code
              ..name = 'previews'
              ..returns = builder.refer('List<WidgetPreview>'),
          )
        ],
      ),
    );
    final emitter = builder.DartEmitter.scoped(useNullSafetySyntax: true);
    await File(
      Directory.current.absolute.uri
          .resolve('.dart_tool/preview_scaffold/lib/generated_preview.dart')
          .toFilePath(),
    ).writeAsString(
      DartFormatter().format('${lib.accept(emitter)}'),
    );
  }

  Future<void> _runPreviewEnvironment() async {
    final projectDir = Directory.current.uri.toFilePath();
    final tempDir = await Directory.systemTemp.createTemp();
    _vmServiceInfoPath = path.join(tempDir.path, 'preview_vm_service.json');
    final process = await runInDirectoryScope<Process>(
      path: previewScaffoldProjectPath,
      callback: () async {
        final args = [
          'run',
          '--machine',
          // ignore: lines_longer_than_80_chars
          if (shouldUsePrebuiltBinary)
            '--use-application-binary=${PlatformUtils.prebuiltApplicationBinaryPath}',
          '--device-id=${PlatformUtils.getDeviceIdForPlatform()}',
          '--vmservice-out-file=$_vmServiceInfoPath',
        ];
        logger.info('Running "${PlatformUtils.flutter} $args"');
        return await Process.start(PlatformUtils.flutter, args);
      },
    );

    late final FlutterToolsDaemon daemon;
    daemon = FlutterToolsDaemon(
      process: process,
      onAppStart: (String appId) async {
        final serviceInfo = await File(_vmServiceInfoPath).readAsString();
        logger.info('Preview VM service can be found at: $serviceInfo');
        // Immediately trigger a hot restart on app start to update state
        daemon.hotRestart();
      },
    );

    _fileWatcher = Watcher(projectDir).events.listen((event) async {
      if (daemon.appId == null ||
          !event.path.endsWith('.dart') ||
          event.path.endsWith('generated_preview.dart')) return;
      final eventPath = event.path.asFilePath;
      logger.info('Detected change in $eventPath. Performing reload...');

      final filePreviewsMapping = _findPreviewFunctions(File(event.path));
      if (filePreviewsMapping.length > 1) {
        logger.warning('Previews from more than one file were detected!');
        logger.warning('Previews: $filePreviewsMapping');
      }
      final MapEntry(key: uri, value: filePreviews) =
          filePreviewsMapping.entries.first;
      logger.info('Updated previews for $uri: $filePreviews');
      if (filePreviews.isNotEmpty) {
        final currentPreviewsForFile = _pathToPreviews[uri];
        if (filePreviews != currentPreviewsForFile) {
          _pathToPreviews[uri] = filePreviews;
        }
      } else {
        _pathToPreviews.remove(uri);
      }

      // Regenerate generated_preview.dart and reload.
      await _populatePreviewsInScaffold(_pathToPreviews);
      daemon.hotReload();
    });

    await process.exitCode;
  }
}
