# P4U Vendor Flutter App

Native Flutter migration of the React Vendor Portal. It uses the Planext4u gateway API and mirrors the vendor routes, visual language, and core workflows without WebView.

## Run

```sh
flutter pub get
flutter run
```

To point at a non-production API, add:

```sh
flutter run --dart-define=P4U_API_BASE_URL=https://api.planext4u.com
```

## Migrated Vendor Areas

- Authentication
- Phone OTP login through Firebase Auth and `/api/auth/public/phone/exchange`
- Vendor registration wizard
- Dashboard
- Products
- Services
- Orders
- Bookings
- Settlements
- Payment history
- Bank accounts
- Availability
- Media library
- Profile
- Wallet
- Account control
- Analytics
- Reviews
- Support
- Notifications
- Settings

## Native Setup Notes

Phone OTP requires native Firebase config for this Flutter app:

- Android: add `android/app/google-services.json`
- iOS: add `ios/Runner/GoogleService-Info.plist`

The app no longer needs `SUPABASE_URL` or `SUPABASE_ANON_KEY` dart-defines.
