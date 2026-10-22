# Contributing to LibreDB Mobile

Contributions are welcome.
This page describes how to report a problem, suggest a change and send code.

## Reporting issues

Report a bug by opening an issue in the [issue tracker](https://github.com/libredb/libredb-mobile/issues).
Give the steps to reproduce it, what you expected, what happened, and any screenshots or logs, with credentials and personal data removed.
Report a security problem privately, as [SECURITY.md](SECURITY.md) describes, not in a public issue.

## Suggesting enhancements

Open an issue with the Feature request form, which adds the `enhancement` label.
Describe the change and why it would be valuable.

## Submitting code

1. Fork the repository and clone your fork:

   ```shell
   git clone https://github.com/<your-account>/libredb-mobile.git
   cd libredb-mobile
   fvm install && fvm flutter pub get
   ```

2. Create a branch for your change:

   ```shell
   git checkout -b your-branch-name
   ```

3. Make your change in the existing code style, with tests for any change in behavior.
   [CLAUDE.md](CLAUDE.md) holds the conventions, and [docs/development.md](docs/development.md) the toolchain.

4. Commit with a [Conventional Commits](https://www.conventionalcommits.org/) message, such as `fix: keep the session after a 401 AUTH_ERROR`.

5. Before you open the pull request, sync your branch with `main`, resolve any conflicts and run:

   ```shell
   fvm dart run intl_utils:generate
   fvm dart format lib/generated --line-length=120
   fvm dart format . --line-length=120 --set-exit-if-changed
   fvm flutter analyze
   fvm flutter test --coverage
   ```

6. Push your branch and open a pull request against `main` of [libredb/libredb-mobile](https://github.com/libredb/libredb-mobile).
   Say what you changed and why, and link the issues it addresses.

## Code style

- Follow the Dart style guide; the line width is 120.
- Include tests for every new feature and bug fix.
- Update the documentation when your change affects it.

## Review

The maintainers review each pull request, may ask for changes, and merge it into `main` once it is ready.

## Code of conduct

By contributing to this project, you agree to follow its [Code of Conduct](CODE_OF_CONDUCT.md).

## Contact

Ask questions in the repository's [Discussions](https://github.com/libredb/libredb-mobile/discussions) or open an issue.
