# Contribute to Index

## Explore Issues

Find issues from the [Issues tab](https://github.com/DataInspectorApp/Data-Inspector/issues). If you find an issue you want to work on, please indicate it in the issue and/or attach a draft PR once available. An admin or maintainer will then assign the Issue and/or PR to you.

> [!IMPORTANT]
> Please make sure to first comment under an issue or ask a maintainer to assign you to the issue before working on it. This helps prevent multiple people from working on the same
> thing, which could result in your work not being merged. Additionally, some issues might be reserved for those with more in-depth knowledge of the codebase.

## Code Style

Please follow the [Google Swift Style Guide](https://google.github.io/swift/).

## Pull Request

Once you are happy with your changes, submit a `Pull Request`.

The pull request opens with a template loaded. Fill out all fields that are relevant.

The `PR` should include following information:
* A descriptive **title** on what changed.
* A detailed **description** of changes.
* If you made changes to the UI please add a **screenshot** or **video** as well.
* If there is a related issue please add a **reference to the issue**. If not, create one beforehand and link it.
* If your PR is still in progress mark it as **Draft**.

### Checks, Tests & Documentation

Request a review from one of our admins @armartinez

> [!TIP]
> If it is your first PR, an admin will need to request a review for you.

> [!IMPORTANT]
> Please resolve all `Violation` errors in Xcode (except: _TODO:_ warnings). Otherwise the swiftlint check on GitHub will fail.

Once you submit the `PR` GitHub will run a couple of actions which run tests and `SwiftLint` (this can take a couple of minutes). Should a test fail, it cannot be merged until tests succeed.

Make sure to resolve all merge-conflicts otherwise the `PR` cannot be merged.
> [!IMPORTANT]
> Make sure your code is well documented so others can interact with your code easily!
