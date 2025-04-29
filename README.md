# EnSens

Mobile application.

```bash
# Prepare system.
# 1.Install Android studio.
# 2.Install Flutter (add bin\ folder to ENV path).
# 3.Open powershell.
# 4.Configure Flutter (once):
flutter config --android-sdk "$env:LOCALAPPDATA\Android\Sdk"
flutter config --jdk-dir "$env:PROGRAMFILES\Android\Android Studio\jbr"
flutter config --enable-android
flutter config --enable-windows-desktop # optional: for development only.
. $profile # Restart commandline shell

# Prepare an app.
cd grc_senseapp # go to the root of this repo
flutter create --platforms android . # required: do this once after clone
flutter create --platforms windows . # optional: do this once after clone

./generate.ps1

# example: run on connected Android device
flutter analyze --suggestions # optional: all should be ok.


# check available an Android device
flutter devices
# example: debugging app on specified Android device
flutter run -d V2352A

# optional: build release apk
flutter build apk

# optional example: install release apk on specified Android device
flutter install -d V2352A
```