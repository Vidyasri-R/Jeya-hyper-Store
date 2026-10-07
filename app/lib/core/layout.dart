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
