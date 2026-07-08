# Vendor Portal Migration Analysis

## React Source Reviewed

- `src/App.tsx`: vendor routes and native app portal detection.
- `src/components/vendor/VendorLayout.tsx`: teal mobile header, desktop/sidebar navigation, bottom nav, menu actions.
- `src/pages/vendor/*`: dashboard, products, services, availability, orders, bookings, settlements, profile, bank accounts, payments, media, account control, password change.
- `src/lib/auth-provider.tsx`: original auth, role checks, vendor status checks, local vendor session model.
- `src/lib/api.ts`: original business logic for vendor dashboard, products, orders, settlements, profile.
- `supabase/migrations/*`: tables used by the Vendor Portal.

## Backend Contracts Preserved

The Flutter app now uses the Planext4u gateway API collection:

- Base URL: `https://api.planext4u.com`
- Auth: `/api/auth/public/phone/exchange`, `/api/auth/public/vendor/register`, `/api/auth/logout`, `/api/auth/change-password`
- Vendor profile: `/api/v1/vendor/me`
- Products: `/api/v1/vendor/me/products`
- Services: `/api/v1/vendor/me/vendor-services`
- Orders/bookings: `/api/v1/vendor/orders`, `/api/v1/vendor/bookings`
- Settlements/plans: `/api/v1/vendor/me/settlements`, `/api/v1/vendor/me/plans`
- Media/documents: `/api/v1/vendor/me/upload`, `/api/v1/vendor/me/documents/upload`, `/api/v1/vendor/me/media/assets`
- Notifications: `/api/v1/notifications/me`

## Native Flutter Mapping

- React Router -> GoRouter
- React Query -> Riverpod `FutureProvider`
- Gateway API calls -> native Dart `HttpClient` API client
- Tailwind/shadcn cards -> Material cards and reusable `AppCard`
- `VendorLayout` -> `VendorScaffold`
- Badges -> reusable `StatusBadge`
- Stat cards -> reusable `MetricCard`

## Implemented Feature Modules

- Auth: email/password vendor login, phone OTP bridge through Firebase Auth and the existing Supabase edge function, vendor role lookup, status validation, logout, password update.
- Registration: 5-step vendor application flow with uniqueness checks, state/district lookup, KYC/store logo uploads, bank validation, location capture, and `vendor_applications` submission.
- Dashboard: revenue/order/product/rating cards, chart, recent orders, quick links.
- Products: list, search, status filter, create/update/delete, image upload, CSV import, thumbnail/banner/video/category/parent-item/product-type fields.
- Services: list, search, create/update/delete, image upload, service vendor bootstrap.
- Orders: status tabs, order flow, reject, shipping details.
- Bookings: pending/active/completed sections, accept/reject/start/complete with completion photo upload.
- Settlements and payments: summaries and transaction list.
- Bank accounts: add, set primary, delete.
- Availability: weekly schedule editor with time slots.
- Profile: business details, cover upload, plan/payment status, performance summary, edit contact fields.
- Media library: folder filter, search, upload, delete.
- Analytics, reviews, support, notifications, settings: native pages with live data where existing schema is available.
- Support: native ticket creation against the existing support table.
- Wallet and account control: exposed as native vendor pages; wallet derives from settlements, account deactivate/delete updates vendor status and audit logs.

## Known Follow-Ups

- Native phone OTP requires Firebase Android/iOS configuration and app-specific SHA/package setup before runtime testing.
- Razorpay native checkout should be wired using a Flutter Razorpay plugin if online plan payments must be completed inside the app.
- Image compression currently relies on direct upload; add a Flutter image compression package if WebP parity is required.
- Local compilation could not be performed in this environment because Flutter/Dart SDK commands are not installed.
