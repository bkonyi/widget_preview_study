// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:device_frame/device_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'controls.dart';
import 'utils.dart';

class WidgetPreview extends StatefulWidget {
  const WidgetPreview({
    super.key,
    required this.child,
    this.name,
    this.width,
    this.height,
    this.device,
    this.orientation,
    this.textScaleFactor,
    this.theme,
    this.darkTheme,
    this.platformBrightness,
  });

  /// A description to be displayed alongside the preview.
  final String? name;

  /// The [Widget] to be rendered in the preview.
  final Widget child;

  /// Artificial constraints to be applied to the [child].
  final double? width;
  final double? height;

  /// An optional device configuration.
  final DeviceInfo? device;

  /// The orientation of [device].
  final Orientation? orientation;

  /// Applies font scaling to text within the [child].
  final double? textScaleFactor;

  /// Light and dark theme overrides.
  final ThemeData? theme;
  final ThemeData? darkTheme;

  /// Light or dark mode (defaults to platform theme).
  final Brightness? platformBrightness;

  @override
  State<WidgetPreview> createState() => _WidgetPreviewState();
}

class _WidgetPreviewState extends State<WidgetPreview> {
  final transformationController = TransformationController();
  final deviceOrientation = ValueNotifier<Orientation>(Orientation.portrait);
  final platformBrightness = ValueNotifier<Brightness>(Brightness.light);

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateValueNotifiers();
  }

  @override
  void didUpdateWidget(WidgetPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateValueNotifiers();
  }

  void _updateValueNotifiers() {
    if (widget.orientation case var orientation?) {
      deviceOrientation.value = orientation;
    }
    platformBrightness.value =
        widget.platformBrightness ?? MediaQuery.of(context).platformBrightness;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: platformBrightness,
      builder: (context, brightness, _) {
        return ValueListenableBuilder(
          valueListenable: deviceOrientation,
          builder: (context, orientation, _) {
            final previewerConstraints =
                WidgetPreviewerWindowConstraints.getRootConstraints(context);

            final maxSizeConstraints = previewerConstraints.copyWith(
              minHeight: previewerConstraints.maxHeight / 2.0,
              maxHeight: previewerConstraints.maxHeight / 2.0,
            );

            final orientationSupported = widget.device != null;

            Widget preview = _WidgetPreviewWrapper(
              previewerConstraints: maxSizeConstraints,
              child: Theme(
                data: _getThemeData(context, brightness),
                child: SizedBox(
                  width: widget.width,
                  height: widget.height,
                  child: widget.child,
                ),
              ),
            );

            if (widget.device case DeviceInfo device?) {
              preview = DeviceFrame(
                device: device,
                orientation: orientation,
                screen: preview,
              );

              // Don't let the device frame get too large.
              if (device.frameSize.height > maxSizeConstraints.biggest.height ||
                  device.frameSize.width > maxSizeConstraints.biggest.width) {
                preview = SizedBox.fromSize(
                  size: maxSizeConstraints.constrain(device.frameSize),
                  child: preview,
                );
              }
            }

            preview = MediaQuery(
              data: _buildMediaQueryOverride(brightness),
              child: preview,
            );

            preview = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.name != null) ...[
                  Text(
                    widget.name!,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const VerticalSpacer(),
                ],
                InteractiveViewerWrapper(
                  child: preview,
                  transformationController: transformationController,
                ),
                const VerticalSpacer(),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ZoomControls(
                      transformationController: transformationController,
                    ),
                    if (orientationSupported) ...[
                      const SizedBox(
                        width: 30,
                      ),
                      OrientationButton(
                        orientation: orientation,
                        onPressed: () {
                          deviceOrientation.value =
                              deviceOrientation.value.rotate;
                        },
                      ),
                    ],
                    const SizedBox(
                      width: 30,
                    ),
                    BrightnessButton(
                      lightTheme: widget.theme,
                      darkTheme: widget.darkTheme,
                      brightness: brightness,
                      onPressed: () {
                        platformBrightness.value =
                            platformBrightness.value.invert;
                      },
                    ),
                  ],
                ),
              ],
            );

            return Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16.0,
                  horizontal: 16.0,
                ),
                child: preview,
              ),
            );
          },
        );
      },
    );
  }

  /// The theme is selected based on a few different criteria:
  ///
  ///  - If the [WidgetPreview.platformBrightness] is set, we'll attempt to use
  ///    the theme associated with the brightness ([WidgetPreview.theme] for
  ///    [Brightness.light] and [WidgetPreview.darkTheme]) for [Brightness.dark]
  ///
  ///  - If [WidgetPreview.platformBrightness] isn't set, we'll attempt to use
  ///    [MediaQueryData.platformBrightness] to select the theme.
  ///
  ///  - If the theme for the selected brightness isn't provided, we'll fall
  ///    back to the other provided theme. If no other theme is provided, we
  ///    fallback to the default theme.
  ThemeData _getThemeData(BuildContext context, Brightness platformBrightness) {
    final darkTheme = widget.darkTheme;
    final lightTheme = widget.theme;

    if (lightTheme == null && darkTheme != null) {
      return darkTheme;
    } else if (lightTheme != null && darkTheme == null) {
      return lightTheme;
    } else if (lightTheme == null && darkTheme == null) {
      return Theme.of(context);
    }
    return platformBrightness == Brightness.light ? lightTheme! : darkTheme!;
  }

  MediaQueryData _buildMediaQueryOverride(Brightness platformBrightness) {
    var mediaQueryData = MediaQuery.of(context).copyWith(
      platformBrightness: platformBrightness,
    );

    if (widget.textScaleFactor != null) {
      mediaQueryData = mediaQueryData.copyWith(
        textScaler: TextScaler.linear(widget.textScaleFactor!),
      );
    }

    var size = Size(widget.width ?? mediaQueryData.size.width,
        widget.height ?? mediaQueryData.size.height);

    if (widget.width != null || widget.height != null) {
      mediaQueryData = mediaQueryData.copyWith(
        size: size,
      );
    }

    return mediaQueryData;
  }
}

/// An [InheritedWidget] that propagates the current size of the
/// WidgetPreviewScaffold.
///
/// This is needed when determining how to put constraints on previewed widgets
/// that would otherwise have infinite constraints.
class WidgetPreviewerWindowConstraints extends InheritedWidget {
  const WidgetPreviewerWindowConstraints({
    super.key,
    required super.child,
    required this.constraints,
  });

  final BoxConstraints constraints;

  static BoxConstraints getRootConstraints(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<WidgetPreviewerWindowConstraints>();
    assert(
      result != null,
      'No WidgetPreviewerWindowConstraints founds in context',
    );
    return result!.constraints;
  }

  @override
  bool updateShouldNotify(WidgetPreviewerWindowConstraints oldWidget) {
    return oldWidget.constraints != constraints;
  }
}

class InteractiveViewerWrapper extends StatelessWidget {
  const InteractiveViewerWrapper({
    super.key,
    required this.child,
    required this.transformationController,
  });

  final Widget child;
  final TransformationController transformationController;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: transformationController,
      scaleEnabled: false,
      child: child,
    );
  }
}

/// Wrapper applying a custom render object to force constraints on
/// unconstrained widgets.
class _WidgetPreviewWrapper extends SingleChildRenderObjectWidget {
  const _WidgetPreviewWrapper({
    super.child,
    required this.previewerConstraints,
  });

  /// The size of the previewer render surface.
  final BoxConstraints previewerConstraints;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _WidgetPreviewWrapperBox(
      previewerConstraints: previewerConstraints,
      child: null,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _WidgetPreviewWrapperBox renderObject,
  ) {
    renderObject.setPreviewerConstraints(previewerConstraints);
  }
}

/// Custom render box that forces constraints onto unconstrained widgets.
class _WidgetPreviewWrapperBox extends RenderShiftedBox {
  _WidgetPreviewWrapperBox({
    required RenderBox? child,
    required BoxConstraints previewerConstraints,
  })  : _previewerConstraints = previewerConstraints,
        super(child);

  BoxConstraints _constraintOverride = const BoxConstraints();
  BoxConstraints _previewerConstraints;

  void setPreviewerConstraints(BoxConstraints previewerConstraints) {
    if (_previewerConstraints == previewerConstraints) {
      return;
    }
    _previewerConstraints = previewerConstraints;
    markNeedsLayout();
  }

  @override
  void layout(
    Constraints constraints, {
    bool parentUsesSize = false,
  }) {
    if (child != null && constraints is BoxConstraints) {
      double minInstrinsicHeight;
      try {
        minInstrinsicHeight = child!.getMinIntrinsicHeight(
          constraints.maxWidth,
        );
      } on Object {
        minInstrinsicHeight = 0.0;
      }
      // Determine if the previewed widget is vertically constrained. If the
      // widget has a minimum intrinsic height of zero given the widget's max
      // width, it has an unconstrained height and will cause an overflow in
      // the previewer. In this case, apply finite constraints (e.g., the
      // constraints for the root of the previewer). Otherwise, use the
      // widget's actual constraints.
      _constraintOverride = minInstrinsicHeight == 0
          ? _previewerConstraints
          : const BoxConstraints();
    }
    super.layout(
      constraints,
      parentUsesSize: parentUsesSize,
    );
  }

  @override
  void performLayout() {
    final child = this.child;
    if (child == null) {
      size = Size.zero;
      return;
    }
    final updatedConstraints = _constraintOverride.enforce(constraints);
    child.layout(
      updatedConstraints,
      parentUsesSize: true,
    );
    size = constraints.constrain(child.size);
  }
}
