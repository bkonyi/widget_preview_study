// Copyright 2018 The Flutter team. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:veggieseasons/data/preferences.dart';
import 'package:veggieseasons/data/veggie.dart';
import 'package:veggieseasons/styles.dart';
import 'package:veggieseasons/widgets/settings_group.dart';
import 'package:veggieseasons/widgets/settings_item.dart';

class VeggieCategorySettingsScreen extends StatelessWidget {
  const VeggieCategorySettingsScreen({super.key, this.restorationId});

  final String? restorationId;

  static Page<void> pageBuilder(BuildContext context) {
    return const CupertinoPage(
      restorationId: 'router.categories',
      child: VeggieCategorySettingsScreen(restorationId: 'category'),
      title: 'Preferred Categories',
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Preferences>(context);
    final currentPrefs = model.preferredCategories;
    var brightness = CupertinoTheme.brightnessOf(context);
    return RestorationScope(
      restorationId: restorationId,
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          middle: Text('Preferred Categories'),
          previousPageTitle: 'Settings',
        ),
        backgroundColor: Styles.scaffoldBackground(brightness),
        child: FutureBuilder<Set<VeggieCategory>>(
          future: currentPrefs,
          builder: (context, snapshot) {
            final items = <SettingsItem>[];

            for (final category in VeggieCategory.values) {
              CupertinoSwitch toggle;

              // It's possible that category data hasn't loaded from shared prefs
              // yet, so display it if possible and fall back to disabled switches
              // otherwise.
              if (snapshot.hasData) {
                toggle = CupertinoSwitch(
                  value: snapshot.data!.contains(category),
                  onChanged: (value) {
                    if (value) {
                      model.addPreferredCategory(category);
                    } else {
                      model.removePreferredCategory(category);
                    }
                  },
                );
              } else {
                toggle = const CupertinoSwitch(
                  value: false,
                  onChanged: null,
                );
              }

              items.add(SettingsItem(
                label: veggieCategoryNames[category]!,
                content: toggle,
              ));
            }

            return ListView(
              restorationId: 'list',
              children: [
                SettingsGroup(
                  items: items,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class CalorieSettingsScreen extends StatelessWidget {
  const CalorieSettingsScreen({super.key, this.restorationId});

  final String? restorationId;

  static const max = 1000;
  static const min = 2600;
  static const step = 200;

  static Page<void> pageBuilder(BuildContext context) {
    return const CupertinoPage<void>(
      restorationId: 'router.calorie',
      child: CalorieSettingsScreen(restorationId: 'calorie'),
      title: 'Calorie Target',
    );
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<Preferences>(context);
    var brightness = CupertinoTheme.brightnessOf(context);
    return RestorationScope(
      restorationId: restorationId,
      child: CupertinoPageScaffold(
        navigationBar: const CupertinoNavigationBar(
          previousPageTitle: 'Settings',
        ),
        backgroundColor: Styles.scaffoldBackground(brightness),
        child: ListView(
          restorationId: 'list',
          children: [
            FutureBuilder<int>(
              future: model.desiredCalories,
              builder: (context, snapshot) {
                final steps = <SettingsItem>[];

                for (var cals = max; cals < min; cals += step) {
                  steps.add(
                    SettingsItem(
                      label: cals.toString(),
                      icon: SettingsIcon(
                        icon: Styles.checkIcon,
                        foregroundColor:
                            snapshot.hasData && snapshot.data == cals
                                ? CupertinoColors.activeBlue
                                : Styles.transparentColor,
                        backgroundColor: Styles.transparentColor,
                      ),
                      onPress: snapshot.hasData
                          ? () => model.setDesiredCalories(cals)
                          : null,
                    ),
                  );
                }

                return SettingsGroup(
                  items: steps,
                  header: const SettingsGroupHeader('Available calorie levels'),
                  footer:
                      const SettingsGroupFooter('These are used for serving '
                          'calculations'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({this.restorationId, super.key});

  final String? restorationId;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SettingsItem _buildCaloriesItem(BuildContext context, Preferences prefs) {
    return SettingsItem(
      label: 'Calorie Target',
      icon: const SettingsIcon(
        backgroundColor: Styles.iconBlue,
        icon: Styles.calorieIcon,
      ),
      content: FutureBuilder<int>(
        future: prefs.desiredCalories,
        builder: (context, snapshot) {
          return Row(
            children: [
              Text(
                snapshot.data?.toString() ?? '',
                style: CupertinoTheme.of(context).textTheme.textStyle,
              ),
              const SizedBox(width: 8),
              const SettingsNavigationIndicator(),
            ],
          );
        },
      ),
      onPress: () {
        context.go('/settings/calories');
      },
    );
  }

  SettingsItem _buildCategoriesItem(BuildContext context, Preferences prefs) {
    return SettingsItem(
      label: 'Preferred Categories',
      subtitle: 'What types of veggies you prefer!',
      icon: const SettingsIcon(
        backgroundColor: Styles.iconGold,
        icon: Styles.preferenceIcon,
      ),
      content: const SettingsNavigationIndicator(),
      onPress: () {
        context.go('/settings/categories');
      },
    );
  }

  SettingsItem _buildRestoreDefaultsItem(
      BuildContext context, Preferences prefs) {
    return SettingsItem(
      label: 'Restore Defaults',
      icon: const SettingsIcon(
        backgroundColor: CupertinoColors.systemRed,
        icon: Styles.resetIcon,
      ),
      content: const SettingsNavigationIndicator(),
      onPress: () {
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('Are you sure?'),
            content: const Text(
              'Are you sure you want to reset the current settings?',
            ),
            actions: [
              CupertinoDialogAction(
                isDestructiveAction: true,
                child: const Text('Yes'),
                onPressed: () async {
                  await prefs.restoreDefaults();
                  if (!context.mounted) return;
                  context.pop();
                },
              ),
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('No'),
                onPressed: () => context.pop(),
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = Provider.of<Preferences>(context);

    return RestorationScope(
      restorationId: widget.restorationId,
      child: CupertinoPageScaffold(
        child: Container(
          color:
              Styles.scaffoldBackground(CupertinoTheme.brightnessOf(context)),
          child: CustomScrollView(
            restorationId: 'list',
            slivers: [
              const CupertinoSliverNavigationBar(
                largeTitle: Text('Settings'),
              ),
              SliverSafeArea(
                top: false,
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    [
                      SettingsGroup(
                        items: [
                          _buildCaloriesItem(context, prefs),
                          _buildCategoriesItem(context, prefs),
                          _buildRestoreDefaultsItem(context, prefs),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
