# MirrorChild Localization

This folder contains the localization files for the MirrorChild app.

## Structure

- `en.lproj`: English localization
- `ja.lproj`: Japanese localization

Each folder contains:
- `Localizable.strings`: Contains all the text strings used in the app

## How to use

In the code, use the extension methods:

```swift
// For text displayed in the UI
Text("keyName".localized)

// For programmatic strings
let message = "keyName".localized

// For strings with parameters
let formatted = "welcomeUser".localized(with: userName)
```

## Adding a new language

1. Create a new folder with the language code, e.g., `fr.lproj` for French
2. Copy the `Localizable.strings` file from the `en.lproj` folder
3. Translate all the strings to the new language
4. Add the new language to the `CFBundleLocalizations` array in the `Info.plist` file

## Adding new strings

1. Add the new string to all `Localizable.strings` files
2. Use the following format:
   ```
   "keyName" = "Localized string";
   ```
3. Make sure the key is the same in all files