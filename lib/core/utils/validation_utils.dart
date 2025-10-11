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
  /// Only accepts 8-digit numbers starting with 5, 6, or 9
  static bool isValidKuwaitPhone(String phone) {
    if (phone.isEmpty) {
      return false; // Phone is required
    }

    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Must be exactly 8 digits starting with 5, 6, or 9
    final RegExp kwRegex = RegExp(r'^[569]\d{7}$');
    return kwRegex.hasMatch(digitsOnly);
  }

  /// Normalizes Kuwait phone input to E.164 format with +965 prefix
  /// Input should be 8 digits starting with 5, 6, or 9
  static String normalizeKuwaitPhone(String phone) {
    if (phone.isEmpty) {
      return '';
    }

    // Remove all non-digit characters
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');

    // Must be exactly 8 digits starting with 5, 6, or 9
    if (RegExp(r'^[569]\d{7}$').hasMatch(digitsOnly)) {
      return '+965$digitsOnly';
    }

    // Return empty string if invalid format
    return '';
  }
}
