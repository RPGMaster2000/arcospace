# Android debug builds

Every push to `main` runs **Build Android debug APK**. You can also open that workflow in GitHub Actions and choose **Run workflow** on `main`.

On your phone:

1. Sign into GitHub in your browser and open https://github.com/RPGMaster2000/arcospace/actions/workflows/android.yml.
2. Open a successful run and scroll to **Artifacts**. Download `arcospace-android-debug-<run>-<commit>` (a ZIP).
3. Extract it in Files and tap `arcospace-debug.apk`. Allow installation from that browser/file manager when Android asks.
4. Launch Arcospace. The Android preset enables immersive fullscreen and the project explicitly retains landscape orientation. CI checks the APK signature and landscape manifest; check actual display and gameplay on your phone.

Artifacts expire after 30 days. Run the workflow again if a download has expired. These are development APKs, not Play Store releases.

## Signing and updates

No key or password is committed, cached, or uploaded. Without secrets, each run generates a temporary private debug key and removes it afterwards. This works immediately, but APKs from different runs cannot update each other in place. Android may say "App not installed" or report a conflicting package. Back up any needed app data before uninstalling the old app; uninstalling normally deletes that data.

For repeatable updates, add repository **Settings > Secrets and variables > Actions** secrets:

- `ANDROID_DEBUG_KEYSTORE_BASE64`: base64 of a private debug keystore (no headers).
- `ANDROID_DEBUG_KEY_ALIAS`: its alias, default `androiddebugkey`.
- `ANDROID_DEBUG_KEY_PASSWORD`: its store/key password (must be the same), default `android`.

Use a dedicated development key, never a production signing key. Keep a private backup outside GitHub. For example, generate one on a machine with Java, then base64-encode the file and paste the result directly into the secret:

```sh
keytool -genkeypair -storetype JKS -keystore arcospace-debug.keystore \
  -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000
base64 -w 0 arcospace-debug.keystore
```

Do not commit the keystore or base64 output. If you can privately recover the debug key used by the phone editor, using that same key and package ID can allow upgrading the existing app. Otherwise the first CI APK cannot replace it in place. Merely using the same alias/password does not recreate the same key. Changing the secret key later also requires a reinstall. CI uses the workflow run number as Android version code; installing an older version may be rejected.

## Pinned export configuration

- Godot **4.7.2 stable**, matching the existing web workflow and the project's 4.7 feature version; engine and official templates are checked against fixed SHA-256 digests.
- Ubuntu 24.04, Temurin Java **17.0.16+8**, Android command-line tools **13114758**, SDK platform **36**, build tools **36.1.0** (matching Godot 4.7.2's `platform/android/java/app/config.gradle`). Platform-tools are installed by SDK Manager; that rolling package does not compile/sign the APK.
- Standard precompiled Android templates, no Gradle/native compilation, so NDK/CMake are unnecessary. ARM32 and ARM64 are included. The Mobile renderer and gameplay stay unchanged.
- No Android preset or explicit package ID existed in the repository. `com.example.arcospace` is inferred from Godot's default `com.example.$genname` and project name `Arcospace`; check your phone's old export if you customized it locally.
- Immersive fullscreen is enabled in the Android preset. Explicit landscape `0` preserves Godot's existing default. The Web preset and workflow are unchanged.

Upgrading Godot requires updating both download checksums, templates, editor-settings filename, and Android requirements together. This pins the export toolchain, but does not promise byte-identical APKs: signing, run-number version codes, and archive timestamps can differ.
