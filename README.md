<p align="center">
  <img src="https://github.com/try-index/Index/blob/main/.github/256.png?raw=true" height="128">
  <h1 align="center">Index</h1>
</p>

A native macOS database client for the SQLite databases used in app development.
Index opens SQLite files, including Core Data and SwiftData stores, so you can explore their tables and records and edit them in place. It can also find the databases inside the apps installed in Xcode's simulators, without hunting through their folders.

> [!IMPORTANT]
> Index is an early version under active development, so you may run into bugs and rough edges. If you do, please [report them](https://github.com/try-index/Index/issues/new/choose).
>
> Contributions are encouraged and welcome, whether it's a fix, a feature or an improvement to the documentation: see the [Contribution Guide](https://github.com/try-index/Index/blob/main/CONTRIBUTING.md) to get started.

## Get started

### Requirements

- macOS 14.6 or later

### Install

Download Index from the [Mac App Store](https://apps.apple.com/es/app/index-db-client/id6758145306?l=en-GB&mt=12).

## Documentation

Guides and reference live in the [Index wiki](https://github.com/try-index/Index/wiki):

- Opening database files and simulator databases
- Exploring and editing records
- Core Data and SwiftData stores
- Building the app from source

## Community

- Report a bug or request a feature by [opening an issue](https://github.com/try-index/Index/issues/new/choose).
- Read the [Contribution Guide](https://github.com/try-index/Index/blob/main/CONTRIBUTING.md) before sending a pull request.

This is a community-led effort, so we welcome as many contributors who can help.

<a href="https://www.buymeacoffee.com/armartinez" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-blue.png" alt="Buy Me A Coffee" height="41" width="174"></a>

## Development

[![Build](https://github.com/try-index/Index/actions/workflows/index-build.yml/badge.svg)](https://github.com/try-index/Index/actions/workflows/index-build.yml)

- Open `Index.xcodeproj` in Xcode 26 or later. Copy `Configuration/Local.xcconfig.example` to `Configuration/Local.xcconfig` and set your team ID to sign the app.
- [AGENTS.md](AGENTS.md) describes the architecture, conventions and commands, for contributors and coding agents alike.

## License

**Index is free, and will always be free.**

### The app

Download it from the Mac App Store and use it however you like — personally, at
work, or across your company. The released app is licensed to you under Apple's
standard end user terms, and costs nothing.

### The source code

The code in this repository is licensed
under the [PolyForm Noncommercial License 1.0.0](LICENSE.md):

- ✅ Read it, build it, and modify it
- ✅ Fork it and contribute changes back
- ✅ Use it for personal projects, study, and research
- ✅ Use it at nonprofits, schools, and government institutions
- ❌ Use it, or any part of it, for commercial purposes
- ❌ Sell it, or sell anything built from it

The intent is simple: development tools should be free. You should never have to
pay for this, and neither should anyone else — so nobody gets to take this work,
in whole or in part, and sell it.

Donations are welcome and unaffected by the license. If you need a commercial
license, open an issue.

> Releases published before this change were licensed under the MIT License and
> remain available under those terms.

---

Index is an independent project and is not affiliated with, endorsed by or sponsored by Apple Inc. Apple, Mac, macOS, Xcode and Mac App Store are trademarks of Apple Inc., registered in the U.S. and other countries.

Copyright © 2024–2026 Axel Martinez.
