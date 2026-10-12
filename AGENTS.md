# AGENTS.md

Guidance for coding agents working in this repository.

## Build / Format

The project is a single Xcode project with two schemes:

- `Development` builds the app and the `SQLite` library it embeds. Use it for everyday work and CI.
- `App Store` is the scheme used for releases.

There are no tests yet.

Signing reads `DEVELOPMENT_TEAM` from `Configuration/Local.xcconfig`, which is ignored by git. Copy `Configuration/Local.xcconfig.example` and fill in a team ID. Don't set the team in the target's Signing & Capabilities tab: that writes it into the project file.

```bash
xcodebuild -project Index.xcodeproj -scheme Development -destination 'platform=macOS' build
```

```bash
swift format lint --recursive --configuration .swift-format Index SQLite
```

- The app target runs the same lint as its first build phase, so findings show up as warnings in every build.
- CI fails if `swift format` would change any file. `.swift-format` and `.swift-format-nolint` hold the project's style; don't change them. Format only the files you touched: `swift format --configuration .swift-format -i <files>`. Never run it with `respectsExistingLineBreaks: false`.

## Architecture

Index is a macOS database client for the SQLite stores apps use, including Core Data and SwiftData stores. It opens database files the user picks, or ones it finds inside the apps installed in Xcode's simulators.

```
SwiftUI / AppKit views
  → DatabasesManager, SimulatorsManager    (app, @Observable)
  → SQLiteClient                           (SQLite library, actor)
    → SQLiteKit
```

- `IndexApp` declares the windows: a Databases window shown at launch, one window per open database (`WindowGroup(for: Database.ID.self)`), and Settings. It also replaces the File menu with a Database menu.
- `DatabasesManager` keeps the recent databases and their groups, stored in `UserDefaults` with security-scoped bookmarks so the sandboxed app can reopen them.
- `SimulatorsManager` reads `~/Library/Developer/CoreSimulator/Devices` to list the simulators, the apps installed in each, their icons and their database files.
- `SQLiteClient` is an actor that owns one connection. It opens the file through its bookmarks, reads the tables, records and the Core Data model metadata when there is one, and writes edits back.

## SQLite (library target)

- `SQLiteClient.swift`: connecting, read-only mode and the security-scoped access.
- `SQLiteClient+Fetch.swift`: tables, entities, models and records.
- `SQLiteClient+Edit.swift`: adding, updating and deleting records.
- `Models/`: `SQLiteTable` is a plain table; `Entity` is a Core Data entity's table and `Model` a SwiftData model's, both subclasses of it. `SQLiteColumn`, `Property`, `Record` and `Value` describe their contents.

## Index (app target) layout

- `IndexApp.swift`: windows, menus and the managers put in the environment.
- `Managers/`: the `@Observable` objects the app shares through the environment.
- `Models/`: value types (`Database`, `DatabaseGroup`, `Simulator`, `AppInfo`, `TabItem`, …).
- `Views/Databases/`: the Databases window (recents as a grid or list, groups, opening and editing a database).
- `Views/Database/`: a database's window. A sidebar lists its tables, a tab bar holds the open ones, and `Table/` is the `NSTableView` behind the records, with inline editing.
- `Views/Simulators/`: browsing the simulators' apps and their databases.
- `Extensions/`: one `Type+Topic.swift` per extension. `Helpers/` holds the predicate builder, and `Themes/` the colors values are shown in, after Xcode's default theme.
- `Supporting Files/`: Info.plist, assets and entitlements.
- `Resources/` (repository root): sample databases for trying the app.

## Conventions

- **Layout:** write like Apple's Swift packages. 180 columns is a ceiling, not a target: most lines stay under about 110. A call or signature that gets long goes one argument per line, with `)` on its own line. Long `if`/`guard` conditions break at their commas, with `else {` on its own line. Blank lines contain no spaces.
- **Comments:** comment only where the code would otherwise be "fixed" into something broken, and state the reason itself. Don't narrate what the code does or record history.
- **`let` over `var`:** a stored property is `var` only when something writes it after creation.
- **Native over forced:** accept AppKit's and SwiftUI's own sizing and behavior instead of working around them.
- **Sandbox:** the app is sandboxed. File access goes through the user's selection and security-scoped bookmarks; never assume a path is readable.
- **Language mode:** the app target builds in Swift 5 language mode and the `SQLite` library in Swift 6.

## Requirements

- macOS 14.6 or later.
- Xcode 26 or later.
- [vapor/sqlite-kit](https://github.com/vapor/sqlite-kit) and [vapor/sql-kit](https://github.com/vapor/sql-kit), through Swift Package Manager.
