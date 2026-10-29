import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// How far the foot of a modal bottom sheet has to stay clear of the screen's bottom edge: the keyboard while it is up,
/// otherwise the home indicator or the system navigation bar.
///
/// `showModalBottomSheet(useSafeArea: true)` only keeps the sheet out of the top inset, and the keyboard inset
/// (`viewInsets.bottom`) is zero without a keyboard, so a sheet that pads only by the latter ends inside the home
/// indicator. `viewPadding` keeps the system bar's height while the keyboard is up, where `padding` shrinks to zero, so
/// the larger of the two is right in both states.
double sheetBottomInset(BuildContext context) =>
    math.max(MediaQuery.viewInsetsOf(context).bottom, MediaQuery.viewPaddingOf(context).bottom);
