# Password Vault

A local Flutter desktop password manager.

## Security Model

- The vault is stored locally in the app support directory.
- Vault contents are encrypted with AES-GCM.
- The encryption key is derived from the master password with PBKDF2-HMAC-SHA256.
- The master password is never stored.
- Backups use the same encrypted `.pwvault` format for moving to another computer.

## Run

```sh
flutter run -d macos
```

## Build Windows

Flutter Windows apps must be compiled on Windows.

On a Windows computer with Flutter installed:

```powershell
.\scripts\package_windows.ps1
```

The script creates:

```text
dist\PasswordVault-Windows.zip
```

You can unzip it and open `password_vault.exe`.

If this project is pushed to GitHub, the `Build Windows` workflow can also be
run manually from the Actions tab. It uploads `PasswordVault-Windows.zip` as a
downloadable artifact.
