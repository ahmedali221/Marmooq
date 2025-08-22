import 'dart:core';

/// Utility class for input validation with security checks.
class ValidationUtils {
  /// Email validation regex pattern.
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Password validation regex for strong passwords.
  static final RegExp _passwordRegex = RegExp(
    r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$',
  );

  /// Validates email format.
  static bool isValidEmail(String email) {
    if (email.isEmpty) return false;
    return _emailRegex.hasMatch(email.trim());
  }

  /// Validates password strength according to security guidelines.
  /// Requirements:
  /// - At least 8 characters long
  /// - Contains at least one lowercase letter
  /// - Contains at least one uppercase letter
  /// - Contains at least one digit
  /// - Contains at least one special character
  static bool isValidPassword(String password) {
    if (password.isEmpty || password.length < 8) return false;
    return _passwordRegex.hasMatch(password);
  }

  /// Gets password strength description.
  static String getPasswordStrengthMessage(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!RegExp(r'\d').hasMatch(password)) {
      return 'Password must contain at least one digit';
    }
    if (!RegExp(r'[@$!%*?&]').hasMatch(password)) {
      return 'Password must contain at least one special character ';
    }
    return 'Password is strong';
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
}
