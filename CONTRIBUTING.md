# Index Contributor’s Guide

Welcome to the Index community, and thank you for contributing!
This guide explains how to get involved.

* [Licensing](#licensing)
* [Issue Tracking](#issue-tracking)
* [Pull Requests](#pull-requests)
* [AI Contribution Guidelines](#ai-contribution-guidelines)
* [Code of Conduct](#code-of-conduct)
* [Maintainers](#maintainers)

## Licensing

The source code of Index is released under the
[PolyForm Noncommercial License 1.0.0](LICENSE.md), and the app is distributed
on the Mac App Store, which requires Apple's own end-user license terms for the
shipped binary.

By submitting a pull request or otherwise contributing to this project, you
agree that:

1. You are the author of your contribution, or you otherwise have the right to
   submit it under these terms.
2. You grant Axel Martinez a perpetual, worldwide, irrevocable, royalty-free
   license to use, reproduce, modify, and distribute your contribution as part
   of Index — both under the project license and under the license terms
   required by app store distribution channels, including Apple's Licensed
   Application End User License Agreement.
3. You retain copyright in your contribution.

This exists solely so the project can ship through the App Store without a
licensing conflict. It does not transfer ownership of your work.

## Issue Tracking

To file a bug or feature request, use [GitHub](https://github.com/try-index/Index/issues/new/choose)
and fill in the template for it.

Before working on an issue, comment on it or ask a maintainer to assign it to you.
This prevents multiple people from working on the same thing.

## Pull Requests

When preparing a pull request, follow this checklist:

* Imitate the conventions of surrounding code.
* Set your own `DEVELOPMENT_TEAM` in `Configuration/Local.xcconfig` (copy it from `Configuration/Local.xcconfig.example`) rather than in Xcode's Signing & Capabilities tab, which writes it into the project file.
* Format code as described in [Formatting contributions](#formatting-contributions) (otherwise the build will fail).
* Verify that the app builds (`xcodebuild build -project Index.xcodeproj -scheme Development -destination 'platform=macOS'`).
* If you changed the UI, add a screenshot or video to the pull request.
* Follow the [seven rules](https://cbea.ms/git-commit/#seven-rules) of great Git commit messages:
  * Separate subject from body with a blank line.
  * Limit the subject line to 50 characters.[^not-enforced]
  * Capitalize the subject line.
  * Do not end the subject line with a period.
  * Use the imperative mood in the subject line.
  * Wrap the body at 72 characters.[^not-enforced]
  * Use the body to explain what and why vs. how.

> [!IMPORTANT]
> If you plan to make substantial changes or add new features,
> we encourage you to first discuss them by filing a [GitHub Issue](https://github.com/try-index/Index/issues/new/choose).
> This will save time and increases the chance of your pull request being accepted.

[^not-enforced]: This rule is not enforced in the Index project.

### Formatting contributions

Make sure your contributions are consistent with the rest of the project's formatting. Format only the Swift files you changed, using `swift format` and the project's `.swift-format` configuration, so the pull request doesn't pick up changes to files you didn't touch:

```bash
{ git diff --name-only --diff-filter=d main -- '*.swift'; git ls-files --others --exclude-standard -- '*.swift'; } | sort -u | xargs swift format --configuration .swift-format -i
```

This covers every Swift file your branch adds or changes compared with `main`, committed or not. The build runs the linter, so you can check the result before pushing:

```bash
swift format lint --recursive --configuration .swift-format Index SQLite
```

### .gitignore contributions

We do not currently accept contributions to add editor specific additions to the root `.gitignore`. We urge contributors to make a global `.gitignore` file with the rulesets they may want to add instead. A global `.gitignore` file can be set like so:

```bash
git config --global core.excludesfile ~/.gitignore
```

## AI Contribution Guidelines

We welcome thoughtful use of AI tools in your contributions to this repository. We ask that you adhere to these rules in order to preserve the project's integrity, clarity, and quality, and to respect maintainer bandwidth:

* You should be able to explain and justify every line of code or documentation that was generated or assisted by AI. Your submission should reflect your own understanding and intent.
* Use AI to augment, not totally replace, your reasoning or familiarity, especially for non-trivial parts of the system.
* Avoid dumping AI-generated walls of text that you cannot explain. Low-effort, unexplained submissions will be deprioritized to protect maintainer bandwidth.

## Code of Conduct

To clarify what is expected of our contributors and community members, Index has adopted the code of conduct defined by the Contributor Covenant. For more detail, please read the [Code of Conduct](CODE_OF_CONDUCT.md).

## Maintainers

The project’s maintainer is [@armartinez](https://github.com/armartinez). Request a review from them once your pull request is ready.
