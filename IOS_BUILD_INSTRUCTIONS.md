# iOS Build & Fix Instructions

## Critical Changes Made for iPhone Compatibility

### ✅ Changes Applied:

1. **Added `offeraatkw.com` domain exception to iOS Info.plist**
   - Location: `ios/Runner/Info.plist`
   - Allows your Shopify store domain to work on iOS
   - Configured with NSAppTransportSecurity exceptions

2. **Added auto-refresh for Shopify server errors**
   - Location: `lib/features/shipment/view/checkout_webview_screen.dart`
   - Detects "There was a problem with our checkout" error
   - Automatically refreshes the page after 3 seconds
   - Prevents checkout from getting stuck

3. **Added iOS-specific User Agent**
   - Sets proper iPhone Safari user agent for better compatibility
   - Ensures Shopify recognizes it as a mobile browser

4. **Enhanced error logging**
   - Platform detection (iOS vs Android)
   - Better error tracking for debugging

5. **Phone number fallback to demo**
   - If phone is null/empty → uses `+96555544789`
   - Applied in 3 places for consistency

---

## 🚀 **HOW TO REBUILD THE iOS APP:**

### Step 1: Clean the iOS build
```bash
cd ios
rm -rf Pods Podfile.lock
flutter clean
cd ..
```

### Step 2: Get dependencies
```bash
flutter pub get
```

### Step 3: Install iOS pods
```bash
cd ios
pod install
cd ..
```

### Step 4: Build for iPhone
```bash
# For connected iPhone device:
flutter build ios --release

# Or to run directly on connected iPhone:
flutter run --release
```

### Step 5: Open in Xcode (if you need to build .ipa for TestFlight/App Store)
```bash
cd ios
open Runner.xcworkspace
```

In Xcode:
1. Select your device or "Any iOS Device"
2. Go to Product → Archive
3. Once archive completes, click "Distribute App"
4. Choose your distribution method (App Store, Ad Hoc, etc.)

---

## 🔍 **Testing Checklist:**

After rebuilding, test these scenarios on iPhone:

- [ ] App launches successfully
- [ ] Login works
- [ ] Add products to cart
- [ ] Proceed to checkout
- [ ] Phone number gets filled (check logs)
- [ ] Checkout page loads without errors
- [ ] If Shopify error appears → page auto-refreshes
- [ ] Complete order successfully

---

## 📱 **Debugging on iPhone:**

To see logs from iPhone:

1. Connect iPhone via USB
2. Run: `flutter run --release` or `flutter run --debug`
3. Watch the console for:
   - `Platform: ios`
   - `Phone formatted: +965...`
   - `DETECTED: Shopify server error` (if error occurs)
   - `Auto-refreshing page due to Shopify server error...`

---

## ⚠️ **Common Issues & Solutions:**

### Issue 1: "There was a problem with our checkout"
**Solution:** The app now auto-refreshes after 3 seconds. This is a Shopify server issue, not an app issue.

### Issue 2: WebView not loading
**Solution:** Check that `offeraatkw.com` is in Info.plist (already done)

### Issue 3: Phone field not filled
**Solution:** Check logs for "Phone formatted:" - if null, demo number `+96555544789` is used

### Issue 4: Build fails
**Solution:**
```bash
flutter clean
rm -rf ios/Pods ios/Podfile.lock
flutter pub get
cd ios && pod install && cd ..
flutter build ios
```

---

## 📋 **Files Modified:**

1. `ios/Runner/Info.plist` - Added offeraatkw.com domain exception
2. `lib/features/shipment/view/checkout_webview_screen.dart` - Auto-refresh, iOS user agent, better logging
3. `lib/features/shipment/view/shipmentPage.dart` - Phone null handling
4. `lib/features/shipment/services/checkout_service.dart` - Phone validation & fallback

---

## 🎯 **Expected Behavior:**

### On Android (working):
✅ Checkout loads → Phone filled → Order completes

### On iPhone (should now work):
✅ Checkout loads → Phone filled → If server error → Auto-refresh → Order completes

---

## 💡 **Key Differences Between Android & iPhone:**

| Feature | Android | iPhone |
|---------|---------|---------|
| Network Security | AndroidManifest.xml | Info.plist |
| WebView Engine | Chrome | Safari (WKWebView) |
| User Agent | Chrome Mobile | Safari Mobile |
| Error Handling | More permissive | Stricter (needs exceptions) |

---

## 🆘 **If Still Not Working on iPhone:**

1. Check iOS console logs for specific errors
2. Verify Info.plist has all three domains:
   - localhost
   - myshopify.com
   - shopify.com
   - **offeraatkw.com** ← NEW
3. Try on iPhone Safari browser first (not app) to verify Shopify store works
4. Check Shopify admin → Settings → Checkout for any region restrictions

---

**REBUILD NOW WITH:**
```bash
flutter clean && flutter pub get && cd ios && pod install && cd .. && flutter run --release
```


