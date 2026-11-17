# Expense Tracker

Shared Flutter expense/income tracker for a small workspace team.

## Features

- Email/password + Google registration with Admin / Super Admin role picker
- Locked “who added” attribution (entries always under the signed-in user)
- Dashboard: numeric totals + charts (category + per-user)
- Month/year filtering
- Reminders (electricity, project host, room rent, custom) with monthly repeat
- Biometric and/or app PIN unlock after login
- Super Admin user approval and role management

## Quick start

Cloud Supabase project **`expense_tracker`** is wired in
[`lib/core/app_config.dart`](lib/core/app_config.dart). Schema is applied.

```bash
cd "/Users/rabeeh/expense tracker"
flutter pub get
flutter run
```

First account: register as **Super Admin**.

Google Sign-In is optional (needs Google Cloud OAuth + `GOOGLE_WEB_CLIENT_ID`).

## Stack

Flutter · BLoC · GoRouter · Supabase · fl_chart · local_auth · flutter_secure_storage
