# Contributing to LibreDB Mobile

LibreDB Mobile is source-available under the [Elastic License 2.0](LICENSE), and SEKOYA GRUP BİLİŞİM VE TEKNOLOJİ LİMİTED ŞİRKETİ develops it.
We do not accept pull requests from outside the team at this time, so that SEKOYA GRUP BİLİŞİM VE TEKNOLOJİ LİMİTED ŞİRKETİ keeps the right to license all of the code.
Only collaborators of the repository can open a pull request, so an outside contributor opens an issue instead, and we will consider the change.
For licensing, write to info@libredb.org.

When this project starts to accept outside contributions, this file will say how, and under which contributor agreement.

## Reporting issues

Report a bug by opening an issue in the [issue tracker](https://github.com/libredb/libredb-mobile/issues).
Give the steps to reproduce it, what you expected, what happened, and any screenshots or logs, with credentials and personal data removed.
Report a security problem privately, as [SECURITY.md](SECURITY.md) describes, not in a public issue.

## Suggesting enhancements

Open an issue with the Feature request form, which adds the `enhancement` label.
Describe the change and why it would be valuable.

Offer a translation the same way, as an issue with the new or corrected texts.

## Submitting code (team members)

1. Clone the repository:

   ```shell
   git clone https://github.com/libredb/libredb-mobile.git
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

6. Push your branch and open a pull request against `main`.
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

Ask questions in the [issue tracker](https://github.com/libredb/libredb-mobile/issues).
