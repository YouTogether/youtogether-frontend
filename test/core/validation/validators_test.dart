import 'package:flutter_test/flutter_test.dart';
import 'package:youtogether/core/validation/validators.dart';

void main() {
  group('Validators.isValidEmail', () {
    test('should accept a plausible email address', () {
      expect(Validators.isValidEmail('test@example.com'), isTrue);
    });

    test('should accept an email with a subdomain', () {
      expect(Validators.isValidEmail('user@mail.example.co.uk'), isTrue);
    });

    test('should accept an email with a plus tag', () {
      expect(Validators.isValidEmail('user+tag@example.com'), isTrue);
    });

    test('should reject a string with no @ symbol', () {
      expect(Validators.isValidEmail('not-an-email'), isFalse);
    });

    test('should reject a string with no domain', () {
      expect(Validators.isValidEmail('user@'), isFalse);
    });

    test('should reject a string with no local part', () {
      expect(Validators.isValidEmail('@example.com'), isFalse);
    });

    test('should reject an empty string', () {
      expect(Validators.isValidEmail(''), isFalse);
    });

    test('should reject a string containing whitespace', () {
      expect(Validators.isValidEmail('user @example.com'), isFalse);
    });
  });
}
