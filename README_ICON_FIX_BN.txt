LIFE INBOX — ANDROID ICON FIX

This patch contains only app-icon assets. It does not replace lib/main.dart or other app code.

HOW TO APPLY (Windows):
1. Close the running app (keep the existing project folder).
2. Extract this ZIP directly into the existing life_inbox project root — the folder that contains pubspec.yaml. Choose Replace/Overwrite if Windows asks.
3. Confirm the extracted paths merge as android\app\src\main\res\... and assets\images\app_icon.png. Do not create a nested life_inbox\life_inbox folder.
4. In VS Code Terminal, run these commands one at a time:
   flutter clean
   flutter pub get
   flutter run -d emulator-5554

If Android still displays a cached old icon, remove the old Life Inbox shortcut from the launcher and reopen it from the app drawer. If the app drawer icon remains stale, a reinstall may be needed; uninstalling clears local app preferences/data, so preserve anything important first.

The icon uses the existing Life Inbox logo mark, transparent foreground for Android adaptive icons, and a navy (#061526) background.
