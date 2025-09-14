import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service for handling security-related operations.
class SecurityService {
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _accessTokenKey = 'shopify_access_token';
  static const String _refreshTokenKey = 'shopify_refresh_token';
  static const String _userDataKey = 'encrypted_user_data';
  static const String _sessionIdKey = 'session_id';
  static const String _cartIdKey = 'shopify_cart_id';

  /// Stores access token securely using Flutter Secure Storage.
  static Future<void> storeAccessToken(String token) async {
    await _secureStorage.write(key: _accessTokenKey, value: token);
  }

  /// Retrieves stored access token.
  static Future<String?> getAccessToken() async {
    return await _secureStorage.read(key: _accessTokenKey);
  }

  /// Stores refresh token securely.
  static Future<void> storeRefreshToken(String token) async {
    await _secureStorage.write(key: _refreshTokenKey, value: token);
  }

  /// Retrieves stored refresh token.
  static Future<String?> getRefreshToken() async {
    return await _secureStorage.read(key: _refreshTokenKey);
  }

  /// Stores user data with encryption.
  static Future<void> storeUserData(Map<String, dynamic> userData) async {
    final jsonString = jsonEncode(userData);
    final encryptedData = _encryptData(jsonString);
    await _secureStorage.write(key: _userDataKey, value: encryptedData);
  }

  /// Retrieves and decrypts user data.
  static Future<Map<String, dynamic>?> getUserData() async {
    final encryptedData = await _secureStorage.read(key: _userDataKey);
    if (encryptedData == null) return null;

    try {
      final decryptedData = _decryptData(encryptedData);
      return jsonDecode(decryptedData) as Map<String, dynamic>;
    } catch (e) {
      // If decryption fails, clear corrupted data
      await clearUserData();
      return null;
    }
  }

  /// Generates a unique session ID.
  static Future<void> generateSessionId() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final sessionId = _hashString(timestamp);
    await _secureStorage.write(key: _sessionIdKey, value: sessionId);
  }

  /// Gets current session ID.
  static Future<String?> getSessionId() async {
    return await _secureStorage.read(key: _sessionIdKey);
  }

  /// Clears all stored authentication data.
  static Future<void> clearAllAuthData() async {
    await _secureStorage.delete(key: _accessTokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
    await _secureStorage.delete(key: _userDataKey);
    await _secureStorage.delete(key: _sessionIdKey);

    // Also clear any non-secure preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('shopify_access_token');
    await prefs.remove('user_data');
  }

  /// Clears user data only.
  static Future<void> clearUserData() async {
    await _secureStorage.delete(key: _userDataKey);
  }

  /// Checks if user has valid authentication.
  static Future<bool> hasValidAuth() async {
    final token = await getAccessToken();
    final sessionId = await getSessionId();
    return token != null && token.isNotEmpty && sessionId != null;
  }

  /// Simple encryption for user data (Base64 encoding with salt).
  static String _encryptData(String data) {
    final salt = 'traincode_salt_2024';
    final saltedData = salt + data + salt;
    final bytes = utf8.encode(saltedData);
    return base64.encode(bytes);
  }

  /// Simple decryption for user data.
  static String _decryptData(String encryptedData) {
    final salt = 'traincode_salt_2024';
    final bytes = base64.decode(encryptedData);
    final saltedData = utf8.decode(bytes);

    // Remove salt from both ends
    if (saltedData.startsWith(salt) && saltedData.endsWith(salt)) {
      return saltedData.substring(salt.length, saltedData.length - salt.length);
    }
    throw Exception('Invalid encrypted data');
  }

  /// Creates a hash of the input string.
  static String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Validates token format (basic check).
  static bool isValidTokenFormat(String token) {
    // Basic validation - Shopify access tokens are typically 32+ characters
    return token.isNotEmpty && token.length >= 32 && !token.contains(' ');
  }

  /// Checks if token is likely expired based on creation time.
  static bool isTokenLikelyExpired(String token) {
    // This is a basic check - in a real app, you'd decode the token
    // or store the expiration time separately
    // For now, we'll assume tokens are valid for 24 hours
    // This would need to be enhanced with actual token expiration logic
    return false; // Placeholder - implement based on your token structure
  }

  /// Stores token expiration date.
  static Future<void> storeTokenExpirationDate(DateTime expirationDate) async {
    final timestamp = expirationDate.millisecondsSinceEpoch.toString();
    await _secureStorage.write(key: 'token_expiration_date', value: timestamp);
  }

  /// Gets token expiration date.
  static Future<DateTime?> getTokenExpirationDate() async {
    final timestamp = await _secureStorage.read(key: 'token_expiration_date');
    if (timestamp == null) return null;

    try {
      final milliseconds = int.parse(timestamp);
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    } catch (e) {
      return null;
    }
  }

  /// Checks if token is expired based on stored expiration date.
  static Future<bool> isTokenExpired() async {
    final expirationDate = await getTokenExpirationDate();
    if (expirationDate == null) return true;

    return DateTime.now().isAfter(expirationDate);
  }

  /// Synchronizes user data with Shopify user.
  static Future<void> syncUserDataWithShopify(
    Map<String, dynamic> userData,
  ) async {
    await storeUserData(userData);

    // Store a simplified version in SharedPreferences for non-sensitive data
    // This can be used for quick access to user display information
    final prefs = await SharedPreferences.getInstance();
    final displayData = <String, dynamic>{
      'email': userData['email'],
      'firstName': userData['firstName'],
      'lastName': userData['lastName'],
      'lastSync': DateTime.now().toIso8601String(),
      'phone': userData['phone'],
    };
    await prefs.setString('user_display_data', jsonEncode(displayData));
  }

  /// Stores cart ID securely.
  static Future<void> storeCartId(String cartId) async {
    await _secureStorage.write(key: _cartIdKey, value: cartId);
  }

  /// Retrieves stored cart ID.
  static Future<String?> getCartId() async {
    return await _secureStorage.read(key: _cartIdKey);
  }

  /// Clears stored cart ID.
  static Future<void> clearCartId() async {
    await _secureStorage.delete(key: _cartIdKey);
  }
}
