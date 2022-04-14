# XCFrameworks

This script will build an xcf file for `libimobiledevice`, `libplist` and `libusbmuxd`. The build xcf file is compatible with macOS x86_64 and arm64 (not catalyst, not iOS and not the iPhoneSimulator). It does so by downloading the corresponding bottles from homebrew. To update this script, open the template file for `libimobiledevice`, `liplist` or `libusbmuxd` with 

```sh
brew edit libimobiledevice
```

and look for the correct sha sum. Replace the sha sum inside of the `build_xcf.sh` with the new one. You might need to update the header files as well. Do not include C++ headers!