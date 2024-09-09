// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

extension OrientationUtils on Orientation {
  Orientation get rotate => this == Orientation.portrait
      ? Orientation.landscape
      : Orientation.portrait;
}

extension BrightnessUtils on Brightness {
  Brightness get invert => this == Brightness.light
      ? Brightness.dark
      : Brightness.light;
}

class VerticalSpacer extends StatelessWidget {
  const VerticalSpacer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 10,
    );
  }
}