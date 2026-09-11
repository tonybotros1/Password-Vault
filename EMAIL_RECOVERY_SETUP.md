# Email recovery setup

The app keeps vault entries on the computer. Supabase stores one random
recovery key for the verified user; it does not store the vault or its entries.

## 1. Create and configure Supabase

1. Create a Supabase project.
2. Open **SQL Editor** and run `supabase/recovery_setup.sql`.
3. Open **Authentication > URL Configuration** and add this exact Additional
   Redirect URL:

   ```text
   passwordvault://recovery-callback
   ```

4. Keep **Confirm email** enabled. For a production installer, configure custom
   SMTP under the authentication email settings.

## 2. Build the Windows app

Get the Project URL and publishable key from the Supabase project's Connect
panel. Never use the secret key or service-role key in the application.

```powershell
C:\flutter\bin\flutter.bat build windows `
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co `
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Then compile `Installer/password_vault_setup.iss` with Inno Setup. The installer
registers `passwordvault://` so the verification and recovery links return to
the running application.

## User flow

1. Unlock the vault and select the recovery-email icon in the header.
2. Enter an email address and click the verification link.
3. If the master password is later forgotten, choose **Forgot Master Password**
   on the unlock screen.
4. Click the emailed recovery link and choose a new master password.

Recovery must be connected and verified before the old master password is lost.
