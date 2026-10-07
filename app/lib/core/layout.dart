import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';

/// The web shop layout (jeyahyperstore.in on laptops and tablets): two-row header, centred page,
/// footer, desktop-style pages. Phones — and the Android/iOS apps on any screen — keep the app layout.
const kWideBreakpoint = 720.0;

/// The widest the page content gets; wider windows show margins either side.
const kMaxContentWidth = 1280.0;

/// Profile, sign-in, addresses, orders and help: easier to read at this width.
const kReadingWidth = 760.0;

/// True for the web shop on a laptop or tablet (inside its frame, even on a narrow reading page).
bool isWideLayout(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<WideLayoutScope>() != null || (kIsWeb && MediaQuery.sizeOf(context).width >= kWideBreakpoint);

/// Marks pages shown inside the web shop frame (see WebFrame).
class WideLayoutScope extends InheritedWidget {
  const WideLayoutScope({super.key, required super.child});

  @override
  bool updateShouldNotify(WideLayoutScope oldWidget) => false;
}

/// Web shop illustration for a category (assets/web/cat_*.webp), matched on its name; null when none fits.
String? categoryArt(String name) {
  final n = name.toLowerCase();
  final key = switch (n) {
    _ when n.contains('rice') => 'rice',
    _ when n.contains('atta') || n.contains('flour') || n.contains('sooji') => 'atta',
    _ when n.contains('dal') || n.contains('pulse') => 'dals',
    _ when n.contains('oil') || n.contains('ghee') => 'oils',
    _ when n.contains('masala') || n.contains('spice') => 'masalas',
    _ when n.contains('salt') || n.contains('sugar') || n.contains('jaggery') => 'salt_sugar',
    _ when n.contains('staple') || n.contains('grocery') => 'staples',
    _ when n.contains('dairy') || n.contains('bread') || n.contains('egg') || n.contains('milk') => 'dairy',
    _ when n.contains('snack') || n.contains('biscuit') => 'snacks',
    _ when n.contains('tea') || n.contains('coffee') || n.contains('bever') => 'beverages',
    _ when n.contains('household') || n.contains('home care') || n.contains('clean') => 'household',
    _ when n.contains('personal') => 'personal_care',
    _ when n.contains('baby') => 'baby_care',
    _ => null,
  };
  return key == null ? null : 'assets/web/cat_$key.webp';
}
