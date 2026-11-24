# ORBIT — Release checklist

Work through this top to bottom. Nothing here costs money until the store
accounts (marked 💳).

## 1. Before every release
- [ ] All tests pass: `godot --headless -s res://tests/run_tests.gd`
- [ ] Played a full game on a real Android phone and/or iPhone
- [ ] Bump the version in **three** places (a test checks they match):
      `project.godot` → `config/version`, and in **Project → Export**:
      Android *Version → Name* + **increase** *Version → Code* (store requires a
      higher number every upload); iOS *Short Version* + *Version*.
- [ ] Update `DEVELOPMENT_LOG.md`

## 2. Android (Google Play)
1. 💳 Create a Google Play Console account (one-time fee).
2. **Create your upload key — once, and keep it forever** (losing it makes
   updates difficult). In a terminal:
   ```
   keytool -genkeypair -v -keystore orbit-upload.keystore -alias orbit -keyalg RSA -keysize 2048 -validity 10000
   ```
   Store the file **and** its password in a safe place (password manager,
   backup). **Never commit it to Git.**
3. In Godot **Project → Export → Android → Keystore → Release**: select the
   keystore, user `orbit`, and the password.
4. Google Play requires an **AAB** (Android App Bundle) for new apps:
   - **Project → Install Android Build Template**
   - In the Android preset: *Gradle Build → Use Gradle Build* = On,
     *Export Format* = AAB.
5. **Export Project** (uncheck "Export With Debug") → upload the `.aab` to an
   **Internal testing** track first, install it via the Play Store on your
   phone, then promote to production.
6. Store listing text: `docs/STORE_LISTING.md`. Data safety form: answer
   "No data collected" (see `docs/PRIVACY_POLICY.md`).

## 3. iOS (App Store)
1. 💳 Join the Apple Developer Program (yearly fee). Requires a Mac with Xcode.
2. In App Store Connect, create the app with bundle ID `com.dinnm16.orbit`.
3. In Godot's iOS preset set your *App Store Team ID*, export, open the Xcode
   project, **Product → Archive → Distribute App → App Store Connect**.
4. Test via **TestFlight** first.
5. App Privacy: "Data Not Collected".

## 4. App ID — decide before the first upload
The app ID `com.dinnm16.orbit` becomes **permanent** once published on Google
Play. Change it now (Project → Export, both presets) if you want something else.
