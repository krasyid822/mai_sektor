import 'package:flutter/services.dart';

class TitleCaseTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    // Capitalize the first letter of each word
    final capitalized = text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    // Maintain selection cursor position
    return newValue.copyWith(
      text: capitalized,
      selection: newValue.selection,
    );
  }
}
