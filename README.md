# CodeBridge Mini 2.0

Portable desktop utility for Windows 10/11 x64. It prepares `AGENT.md` instructions for any AI assistant and turns AI answers into project files.

## Features

- Create projects with names and descriptions in Russian or other languages. A safe Dart/Flutter package slug is generated separately from the display name.
- Built-in and custom `AGENT.md` templates: Flutter Desktop, Flutter Mobile, Flutter Cross-platform and Blank. Templates can be edited, duplicated, created and deleted (built-in templates can be edited but not deleted).
- Template variables: `{{project_name}}`, `{{project_slug}}`, `{{project_description}}`.
- Universal AI answer import: CodeBridge `<<<FILE>>>` markers and Markdown headings / file labels followed by fenced code blocks. Explanatory prose and command-line blocks are ignored.
- Detects likely dependency/configuration fragments. A `pubspec.yaml` dependencies fragment can be merged into an existing pubspec; other fragments require review.
- Preview and select files before writing; overwrite conflicts are confirmed. Relative paths are validated against traversal and Windows reserved names.
- UTF-8 without BOM and LF line endings for generated text files.
- Native Windows title bar. Close hides the app to the system tray; tray menu restores the window or exits completely.
- All app data is stored in `data/` beside the executable. No registry, AppData, startup entry, service or installer is used.

## Build on GitHub

1. Upload the repository contents to the root of a GitHub repository (keep the `.github` folder).
2. Open **Actions** and run **Build CodeBridge Mini (Windows x64)**, or push to `main` / `master`.
3. Download the `CodeBridgeMini-Windows-x64` artifact from the completed workflow.
4. Extract the ZIP and run `code_bridge_mini.exe`.

The workflow uses Flutter 3.24.5 on `windows-2022`, runs `flutter analyze`, `flutter test`, builds the Windows release and packages the portable folder. Creating a tag such as `v2.0.0` also publishes a GitHub Release.

## Local build (Windows)

Requirements: Flutter 3.24.5, Visual Studio 2022 with *Desktop development with C++*, and Windows 10/11 SDK.

```powershell
flutter config --enable-windows-desktop
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build windows --release --no-pub
.\build_portable.ps1
```

The ZIP is written to `portable/CodeBridgeMini-Windows-x64.zip`.

## Portable layout

```text
code_bridge_mini/
  code_bridge_mini.exe
  tray.ico
  data/
    settings.json
    projects/
    templates/
  *.dll
  data/ (created automatically on first launch)
```

Keep the entire extracted folder together when moving it to another PC or USB drive. Do not move only the EXE.

## Import format examples

Explicit format:

```text
<<<FILE: lib/main.dart>>>
void main() {}
<<<END>>>
<<<END_PROJECT>>>
```

Markdown format:

````markdown
### Step 2: Application code (`lib/main.dart`)
Replace the complete file with this code:
```dart
void main() {}
```
````

Dependency snippets such as a `dependencies:` section in `pubspec.yaml` are treated as fragments and are not blindly written over a complete project manifest.

## Notes

- `tray_manager` and `window_manager` are pinned to versions compatible with the Flutter 3.24 line.
- The repository is prepared for GitHub Actions. A successful Windows binary build must be confirmed by the GitHub Actions run on the user's repository; this environment does not include Flutter or the Windows compiler toolchain.
