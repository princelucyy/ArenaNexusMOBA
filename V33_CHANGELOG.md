# V34 CHANGELOG

## Login reliability
- Fixed cloud-first login behavior that could appear stuck when the backend was unreachable.
- Existing local credentials are checked immediately.
- Registration creates the local account immediately; cloud registration runs asynchronously when configured.
- Cloud requests use a shorter 6-second HTTP timeout.
- Added reset-session control.
- Migrates prior V30/V31/V32 save files into a dedicated V34 save file.

## Real-engine UI shell
- New landscape 1280x720 MOBA lobby shell.
- Hero-focused lobby using the supplied Astro Royale artwork.
- Top player/rank/wallet/network bar.
- Left quick-action navigation.
- Bottom navigation bar.
- Classic 5v5 mode card and Match History.
- Restyled Terms/Profile/Tutorial/Match/Result/History screens with the same visual language.

## Authentication providers
- Google OAuth 2.0 start/callback/poll backend flow.
- Facebook OAuth 2.0 start/callback/poll backend flow.
- WhatsApp Business OTP integration contract (provider credentials required).
- Google Play Games native-plugin hook.

## Backend
- V34 provider configuration state is exposed through `/health`.
- Added `identities` and `oauth_pending` SQLite tables.
- Provider flows are explicit and fail clearly when credentials are not configured.
