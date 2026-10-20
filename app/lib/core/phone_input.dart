import 'package:flutter/services.dart';

/// Indian mobile number field: keeps the 10-digit number however it arrives — typed, pasted or
/// offered by the keyboard ("+91 98765 43210", "09876543210", "919876543210" → "9876543210").
class IndianMobileFormatter extends TextInputFormatter {
  const IndianMobileFormatter();

  /// The 10 digits of [input], dropping a leading +91 / 91 / 0.
  static String clean(String input) {
    var digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 10 && digits.startsWith('91')) digits = digits.substring(2);
    // "0" + number (pasted, or typed one key at a time).
    if (digits.length > 10 && digits.startsWith('0')) digits = digits.substring(1);
    return digits.length > 10 ? digits.substring(0, 10) : digits;
  }

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final cleaned = clean(newValue.text);
    if (cleaned == newValue.text) return newValue;
    return TextEditingValue(text: cleaned, selection: TextSelection.collapsed(offset: cleaned.length));
  }
}
