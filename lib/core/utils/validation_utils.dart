import 'dart:core';

/// Utility class for input validation with security checks.
class ValidationUtils {
  /// Email validation regex pattern.
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Password validation regex for passwords with more than 6 characters.
  static final RegExp _passwordRegex = RegExp(r'^.{7,}$');

  /// Validates email format.
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validates password length (more than 6 characters).
  static bool isValidPassword(String password) {
    if (password.isEmpty) return false;
    return _passwordRegex.hasMatch(password);
  }

  /// Gets password strength description.
  static String getPasswordStrengthMessage(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (!RegExp(r'^.{7,}$').hasMatch(password)) {
      return 'Password must be more than 6 characters';
    }
    return 'Password is valid';
  }

  /// Validates name format (non-empty, reasonable length).
  static bool isValidName(String name) {
    if (name.isEmpty) return false;
    final trimmedName = name.trim();
    return trimmedName.length >= 2 && trimmedName.length <= 50;
  }

  /// Gets name validation message.
  static String getNameValidationMessage(String name) {
    if (name.isEmpty) {
      return 'Name is required';
    }
    final trimmedName = name.trim();
    if (trimmedName.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    if (trimmedName.length > 50) {
      return 'Name must be less than 50 characters';
    }
    return 'Name is valid';
  }

  /// Gets email validation message.
  static String getEmailValidationMessage(String email) {
    if (email.isEmpty) {
      return 'Email is required';
    }
    if (!isValidEmail(email)) {
      return 'Please enter a valid email address';
    }
    return 'Email is valid';
  }

  /// Alias for isValidPassword for consistency with UI calls.
  static bool isStrongPassword(String password) {
    return isValidPassword(password);
  }

  /// Sanitizes input string by removing potentially dangerous characters and patterns.
  /// Returns sanitized string safe for processing.
  static String sanitizeInput(String input) {
    if (input.isEmpty) return '';

    // Remove any HTML/script tags
    var sanitized = input.replaceAll(RegExp(r'<[^>]*>'), '');

    // Remove special characters except allowed ones
    sanitized = sanitized.replaceAll(RegExp(r'[^\w\s@.-]'), '');

    // Normalize whitespace
    sanitized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');

    // Limit length to prevent buffer overflow
    if (sanitized.length > 1000) {
      sanitized = sanitized.substring(0, 1000);
    }

    return sanitized;
  }

  /// Sanitizes email input specifically
  static String sanitizeEmail(String email) {
    if (email.isEmpty) return '';

    // Convert to lowercase and remove whitespace
    var sanitized = email.toLowerCase().trim();

    // Only allow valid email characters
    sanitized = sanitized.replaceAll(RegExp(r'[^\w@.-]'), '');

    return sanitized;
  }

  /// Sanitizes name input specifically
  static String sanitizeName(String name) {
    if (name.isEmpty) return '';

    // Remove numbers and special characters
    var sanitized = name.replaceAll(RegExp(r'[^a-zA-Z\s-]'), '');

    // Normalize whitespace
    sanitized = sanitized.trim().replaceAll(RegExp(r'\s+'), ' ');

    return sanitized;
  }

  /// Alias for getPasswordStrengthMessage for consistency with UI calls.
  static String getPasswordValidationMessage(String password) {
    return getPasswordStrengthMessage(password);
  }

  /// Validates phone number format (international E.164).
  static bool isValidPhone(String phone) {
    if (phone.isEmpty) return true; // Optional field
    final RegExp phoneRegex = RegExp(r'^\+?[1-9]\d{1,14}$');
    return phoneRegex.hasMatch(phone.trim());
  }

  /// Gets phone validation message.
  static String getPhoneValidationMessage(String phone) {
    if (phone.isEmpty) return 'Phone is optional';
    if (!isValidPhone(phone)) {
      return 'Please enter a valid international phone number';
    }
    return 'Phone is valid';
  }

  /// Validates a Kuwait mobile phone number.
  /// Accepted inputs:
  /// - Local 8-digit mobile numbers starting with 5, 6, or 9 (e.g., 512345678)
  /// - With country code +965 followed by 8 digits starting with 5, 6, or 9
  /// - With leading zeros/spaces/dashes which will be normalized
  static bool isValidKuwaitPhone(String phone) {
    print('[ValidationUtils] isValidKuwaitPhone called with: "$phone"');
    if (phone.isEmpty) {
      print(
        '[ValidationUtils] Phone is empty, returning true (optional field)',
      );
      return true; // Optional field
    }
    final normalized = normalizeKuwaitPhone(phone);
    print('[ValidationUtils] Normalized phone: "$normalized"');
    // E.164 for Kuwait mobile must be +965 followed by 8 digits starting with 5, 6, or 9
    final RegExp kwRegex = RegExp(r'^\+965[569]\d{7}$');
    final isValid = kwRegex.hasMatch(normalized);
    print('[ValidationUtils] Regex match result: $isValid');
    return isValid;
  }

  /// Normalizes any Kuwait phone input to E.164: +965XXXXXXXX
  /// If input cannot be normalized to a valid mobile number, returns the trimmed original input.
  static String normalizeKuwaitPhone(String phone) {
    print('[ValidationUtils] normalizeKuwaitPhone called with: "$phone"');
    if (phone.isEmpty) {
      print('[ValidationUtils] Phone is empty, returning empty string');
      return '';
    }
    var p = phone.trim();
    print('[ValidationUtils] After trim: "$p"');
    // Remove all non-digits except leading +
    p = p.replaceAll(RegExp(r'[^0-9+]'), '');
    print('[ValidationUtils] After removing non-digits: "$p"');

    // If already E.164 +965XXXXXXXX with valid mobile prefix
    final RegExp e164Kw = RegExp(r'^\+965[569]\d{7}$');
    if (e164Kw.hasMatch(p)) {
      print('[ValidationUtils] Already E.164 format, returning: "$p"');
      return p;
    }

    // If starts with 00965 or 0965 → convert to +965
    if (p.startsWith('00965')) {
      p = '+965' + p.substring(5);
      print('[ValidationUtils] Converted 00965 to: "$p"');
    } else if (p.startsWith('0965')) {
      p = '+965' + p.substring(4);
      print('[ValidationUtils] Converted 0965 to: "$p"');
    }

    // If starts with +965 but has extra leading zero(s)
    if (p.startsWith('+965')) {
      var rest = p.substring(4);
      print('[ValidationUtils] +965 prefix found, rest: "$rest"');
      rest = rest.replaceAll(RegExp(r'^0+'), '');
      print('[ValidationUtils] After removing leading zeros: "$rest"');
      if (rest.length == 8 && RegExp(r'^[569]\d{7}$').hasMatch(rest)) {
        final result = '+965' + rest;
        print('[ValidationUtils] Valid 8-digit mobile, returning: "$result"');
        return result;
      }
    }

    // If local 8-digit number starting with valid mobile prefixes 5/6/9
    var digitsOnly = p.replaceAll(RegExp(r'[^0-9]'), '');
    print('[ValidationUtils] Digits only: "$digitsOnly"');
    digitsOnly = digitsOnly.replaceAll(
      RegExp(r'^965'),
      '',
    ); // Remove leading 965 if present
    print('[ValidationUtils] After removing 965 prefix: "$digitsOnly"');
    digitsOnly = digitsOnly.replaceAll(
      RegExp(r'^0+'),
      '',
    ); // Remove leading zeros
    print('[ValidationUtils] After removing leading zeros: "$digitsOnly"');
    if (digitsOnly.length >= 8) {
      // Truncate to 8 digits if more, then check prefix
      var localNumber = digitsOnly.substring(0, 8);
      print('[ValidationUtils] Local number (8 digits): "$localNumber"');
      if (RegExp(r'^[569]\d{7}$').hasMatch(localNumber)) {
        final result = '+965' + localNumber;
        print('[ValidationUtils] Valid local mobile, returning: "$result"');
        return result;
      }
    }

    // Fallback: return trimmed original if unable to normalize
    final fallback = phone.trim();
    print(
      '[ValidationUtils] Fallback: returning original trimmed: "$fallback"',
    );
    return fallback;
  }
}
