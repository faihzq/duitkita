import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:duitkita/features/trips/trip_widgets.dart';

void main() {
  const formatter = TitleCaseFormatter();

  /// Runs the formatter as the field would, with the caret at the end.
  String format(String text, {String previous = ''}) {
    return formatter
        .formatEditUpdate(
          TextEditingValue(
            text: previous,
            selection: TextSelection.collapsed(offset: previous.length),
          ),
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          ),
        )
        .text;
  }

  group('capitalises word starts', () {
    test('the very first letter, not just after a space', () {
      expect(format('l'), 'L');
      expect(format('langkawi'), 'Langkawi');
    });

    test('every word', () {
      expect(format('langkawi road trip'), 'Langkawi Road Trip');
      expect(format('jeti kuala perlis'), 'Jeti Kuala Perlis');
    });

    test('after punctuation and hyphens', () {
      expect(format('alor setar, kedah'), 'Alor Setar, Kedah');
      expect(format('kuala-perlis'), 'Kuala-Perlis');
      expect(format('penang/kedah'), 'Penang/Kedah');
    });
  });

  group('leaves deliberate casing alone', () {
    test('keeps existing capitals', () {
      expect(format('TS Duty Free'), 'TS Duty Free');
      expect(format('McDonald'), 'McDonald');
    });

    test('does not touch mid-word letters', () {
      expect(format('pulau LANGKAWI'), 'Pulau LANGKAWI');
    });

    test('ignores non-letters at a word start', () {
      expect(format('3 hari 2 malam'), '3 Hari 2 Malam');
    });

    // The Place field accepts pasted lat,lng from a dropped pin — the formatter
    // must not touch it, or the Maps link would break.
    test('leaves pasted coordinates untouched', () {
      expect(format('2.0453, 102.5689'), '2.0453, 102.5689');
      expect(format('6.4414,99.7772'), '6.4414,99.7772');
      expect(format('-6.1751, 106.8650'), '-6.1751, 106.8650');
    });
  });

  group('edit mechanics', () {
    test('empty input passes through', () {
      expect(format(''), '');
    });

    test('preserves the caret position', () {
      const value = TextEditingValue(
        text: 'langkawi road',
        selection: TextSelection.collapsed(offset: 5),
      );
      final out = formatter.formatEditUpdate(TextEditingValue.empty, value);

      expect(out.text, 'Langkawi Road');
      expect(out.selection.baseOffset, 5);
    });

    test('returns the value untouched when nothing needs changing', () {
      const value = TextEditingValue(
        text: 'Langkawi Road',
        selection: TextSelection.collapsed(offset: 13),
        composing: TextRange(start: 9, end: 13),
      );
      final out = formatter.formatEditUpdate(TextEditingValue.empty, value);

      // Composing survives, so autocorrect keeps working mid-word.
      expect(out, same(value));
      expect(out.composing, const TextRange(start: 9, end: 13));
    });

    test('handles a trailing space without crashing', () {
      expect(format('langkawi '), 'Langkawi ');
    });
  });

  test('apply capitalises a comma-separated dish list', () {
    expect(
      TitleCaseFormatter.apply('nasi lemak, roti canai'),
      'Nasi Lemak, Roti Canai',
    );
    expect(TitleCaseFormatter.apply('ABC kopi'), 'ABC Kopi');
  });
}
