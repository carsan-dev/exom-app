import 'package:exom_app/features/trainings/presentation/utils/exercise_text_bullets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('extractExerciseBulletItems', () {
    test('multiline list loses its markers', () {
      expect(
        extractExerciseBulletItems('- Espalda recta\n* Core firme\n• Mirada al frente'),
        ['Espalda recta', 'Core firme', 'Mirada al frente'],
      );
    });

    test('CRLF and blank lines are tolerated', () {
      expect(extractExerciseBulletItems('- Uno\r\n\r\n- Dos\r\n'), ['Uno', 'Dos']);
    });

    test('a single bullet is still a list', () {
      expect(extractExerciseBulletItems('- Solo uno'), ['Solo uno']);
      expect(extractExerciseBulletItems('• Solo uno'), ['Solo uno']);
    });

    test('«-5 kg de lastre» is text', () {
      expect(extractExerciseBulletItems('-5 kg de lastre'), isEmpty);
    });

    test('«*Cuidado* con la rodilla» is text', () {
      expect(extractExerciseBulletItems('*Cuidado* con la rodilla'), isEmpty);
    });

    test('numbers after a marker are content', () {
      expect(extractExerciseBulletItems('- 90 grados'), ['90 grados']);
      expect(
        extractExerciseBulletItems('- 90 grados\n- 3 series'),
        ['90 grados', '3 series'],
      );
    });

    test('numbered list without marker loses its numbers', () {
      expect(
        extractExerciseBulletItems('1. Pie delante\n2) Baja\n3 Sube'),
        ['Pie delante', 'Baja', 'Sube'],
      );
    });

    test('inline bullets are split', () {
      expect(extractExerciseBulletItems('• Uno • Dos'), ['Uno', 'Dos']);
    });

    test('plain text and empty are not lists', () {
      expect(extractExerciseBulletItems('Baja en vertical.'), isEmpty);
      expect(extractExerciseBulletItems('  \n '), isEmpty);
    });
  });
}
