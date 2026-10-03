import 'package:intl/intl.dart';

/// The API sends money and quantities as decimal strings ("68.50", "0.25").
/// We parse them to integer paise / milli-units — never `double` maths — so
/// totals shown in the app always equal what the server charges.
int toPaise(String value) {
  final match = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$').firstMatch(value.trim());
  if (match == null) throw FormatException('Invalid amount: $value');
  final whole = int.parse(match.group(2)!);
  final frac = int.parse((match.group(3) ?? '').padRight(2, '0'));
  final paise = whole * 100 + frac;
  return match.group(1) == '-' ? -paise : paise;
}

int toMilli(String value) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,3}))?$').firstMatch(value.trim());
  if (match == null) throw FormatException('Invalid quantity: $value');
  return int.parse(match.group(1)!) * 1000 + int.parse((match.group(2) ?? '').padRight(3, '0'));
}

/// 1250 → "1.25", 2000 → "2"
String milliToString(int milli) {
  final whole = milli ~/ 1000;
  final frac = (milli % 1000).toString().padLeft(3, '0').replaceFirst(RegExp(r'0+$'), '');
  return frac.isEmpty ? '$whole' : '$whole.$frac';
}

final _rupee = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _rupeeWhole = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

/// "68.50" → "₹68.50"; "60.00" → "₹60" (drops .00 like the design).
String formatRupees(String amount) => formatPaise(toPaise(amount));

String formatPaise(int paise) => paise % 100 == 0 ? _rupeeWhole.format(paise / 100) : _rupee.format(paise / 100);

/// Quantity with unit for display: (1250, "kg") → "1.25 kg"; (2000, "pcs") → "2".
String formatQty(int milli, String unit) {
  final q = milliToString(milli);
  switch (unit) {
    case 'kg':
    case 'g':
    case 'l':
    case 'ml':
      return '$q $unit';
    default:
      return q;
  }
}
