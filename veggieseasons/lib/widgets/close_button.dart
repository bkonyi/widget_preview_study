// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:veggieseasons/styles.dart';

/// Partially overlays and then blurs its child's background.
class FrostedBox extends StatelessWidget {
  const FrostedBox({
    this.child,
    super.key,
  });

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Styles.frostedBackground,
        ),
        child: child,
      ),
    );
  }
}

/// An Icon that implicitly animates changes to its color.
class ColorChangingIcon extends ImplicitlyAnimatedWidget {
  const ColorChangingIcon(
    this.icon, {
    this.color = CupertinoColors.black,
    this.size,
    required super.duration,
    super.key,
  });

  final Color color;

  final IconData icon;

  final double? size;

  @override
  AnimatedWidgetBaseState<ColorChangingIcon> createState() =>
      _ColorChangingIconState();
}

class _ColorChangingIconState
    extends AnimatedWidgetBaseState<ColorChangingIcon> {
  ColorTween? _colorTween;

  @override
  Widget build(BuildContext context) {
    return Icon(
      widget.icon,
      semanticLabel: 'Close button',
      size: widget.size,
      color: _colorTween?.evaluate(animation),
    );
  }

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _colorTween = visitor(
      _colorTween,
      widget.color,
      (dynamic value) => ColorTween(begin: value as Color?),
    ) as ColorTween?;
  }
}

/// A simple "close this modal" button that invokes a callback when pressed.
class CloseButton extends StatefulWidget {
  const CloseButton(this.onPressed, {super.key});

  final VoidCallback onPressed;

  @override
  State<CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<CloseButton> {
  bool tapInProgress = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() => tapInProgress = true);
      },
      onTapUp: (details) {
        setState(() => tapInProgress = false);
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => tapInProgress = false);
      },
      child: ClipOval(
        child: FrostedBox(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: ColorChangingIcon(
                CupertinoIcons.clear_thick,
                duration: const Duration(milliseconds: 300),
                color: tapInProgress
                    ? Styles.closeButtonPressed
                    : Styles.closeButtonUnpressed,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
