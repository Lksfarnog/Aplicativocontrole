import 'package:flutter/services.dart';

class IpAddressInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.length > oldValue.text.length) {
      var digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.length > 12) {
        digitsOnly = digitsOnly.substring(0, 12);
      }

      var newString = <String>[];
      for (int i = 0; i < digitsOnly.length; i++) {
        newString.add(digitsOnly[i]);
        if ((i == 2 || i == 5 || i == 8) && i != digitsOnly.length - 1) {
          newString.add('.');
        }
      }

      final result = newString.join();
      return TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: result.length),
      );
    } else {
      return newValue;
    }
  }
}
