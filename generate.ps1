flutter pub get --no-example

cd packages/ensens_utils
dart run build_runner build --delete-conflicting-outputs
cd -

dart run build_runner build --delete-conflicting-outputs
dart run flutter_launcher_icons
dart run flutter_native_splash:create
# flutter build windows