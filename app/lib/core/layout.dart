import 'package:flutter/widgets.dart';

/// Laptops, desktops and landscape tablets get the web shop layout (top bar, centred page);
/// phones and portrait tablets keep the app layout (bottom tabs).
const kWideBreakpoint = 900.0;

/// The widest the page content gets; wider windows show margins either side.
const kMaxContentWidth = 1280.0;

/// True inside the web shop frame (even on a 760 px reading page) or on any wide screen.
bool isWideLayout(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<WideLayoutScope>() != null || MediaQuery.sizeOf(context).width >= kWideBreakpoint;

/// Marks pages shown inside the wide layout's frame (see WebFrame).
class WideLayoutScope extends InheritedWidget {
  const WideLayoutScope({super.key, required super.child});

  @override
  bool updateShouldNotify(WideLayoutScope oldWidget) => false;
}

/// Cart, checkout, orders, account and sign-in pages: easier to read at this width.
const kReadingWidth = 760.0;
