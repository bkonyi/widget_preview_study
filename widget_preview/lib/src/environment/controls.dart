// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'utils.dart';

class WidgetPreviewIconButton extends StatelessWidget {
  const WidgetPreviewIconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final String tooltip;
  final void Function()? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Ink(
        decoration: ShapeDecoration(
          shape: const CircleBorder(),
          color: onPressed != null ? Colors.lightBlue : Colors.grey,
        ),
        child: IconButton(
          onPressed: onPressed,
          icon: Icon(
            color: Colors.white,
            icon,
          ),
        ),
      ),
    );
  }
}

class ZoomControls extends StatelessWidget {
  const ZoomControls({required this.transformationController});

  final TransformationController transformationController;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WidgetPreviewIconButton(
          tooltip: 'Zoom in',
          onPressed: _zoomIn,
          icon: Icons.zoom_in,
        ),
        const SizedBox(
          width: 10,
        ),
        WidgetPreviewIconButton(
          tooltip: 'Zoom out',
          onPressed: _zoomOut,
          icon: Icons.zoom_out,
        ),
        const SizedBox(
          width: 10,
        ),
        WidgetPreviewIconButton(
          tooltip: 'Reset zoom',
          onPressed: _reset,
          icon: Icons.refresh,
        ),
      ],
    );
  }

  void _zoomIn() {
    transformationController.value = Matrix4.copy(
      transformationController.value,
    ).scaled(1.1);
  }

  void _zoomOut() {
    final updated = Matrix4.copy(
      transformationController.value,
    ).scaled(0.9);

    // Don't allow for zooming out past the original size of the widget.
    // Assumes scaling is evenly applied to the entire matrix.
    if (updated.entry(0, 0) < 1.0) {
      updated.setIdentity();
    }

    transformationController.value = updated;
  }

  void _reset() {
    transformationController.value = Matrix4.identity();
  }
}

class OrientationButton extends StatelessWidget {
  final Orientation orientation;
  final void Function() onPressed;

  const OrientationButton({
    required this.orientation,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return WidgetPreviewIconButton(
      tooltip: 'Rotate to ${orientation.rotate.name}',
      onPressed: onPressed,
      icon: orientation == Orientation.portrait
          ? Icons.landscape
          : Icons.portrait,
    );
  }
}

class BrightnessButton extends StatelessWidget {
  final Brightness brightness;
  final void Function() onPressed;
  final ThemeData? lightTheme;
  final ThemeData? darkTheme;

  const BrightnessButton({
    required this.lightTheme,
    required this.darkTheme,
    required this.brightness,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = true; //lightTheme != null && darkTheme != null;
    var actualBrightness = brightness;
    String tooltip;
    /* if (lightTheme == null && darkTheme != null) {
      actualBrightness = Brightness.dark;
      tooltip = "Provide 'theme' to enable previewing in light mode";
    } else if (lightTheme != null && darkTheme == null) {
      actualBrightness = Brightness.light;
      tooltip = "Provide 'darkTheme' to enable previewing in dark mode";
    } else if (lightTheme == null && darkTheme == null) {
      tooltip = "No theme data available. Provide at least one of 'theme' or "
          "'darkTheme' to preview theming.";
    } else {*/
      tooltip = 'Change to ${brightness.invert.name}';
    //}
    return WidgetPreviewIconButton(
      tooltip: tooltip,
      onPressed: enabled ? onPressed : null,
      icon: actualBrightness == Brightness.light
          ? Icons.dark_mode
          : Icons.light_mode,
    );
  }
}
