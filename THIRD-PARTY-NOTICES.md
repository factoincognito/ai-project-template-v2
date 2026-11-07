# Third-party notices

Third-party components this repository uses. Template-only: this file is
not in `bootstrap/manifest.txt`, so it is not in the bootstrapper and not
in the projects made from it.

## bashcov 4.0.2

- Licence: MIT
- Source: https://github.com/infertux/bashcov, installed as the gem
  bashcov 4.0.2 from https://rubygems.org/downloads/bashcov-4.0.2.gem
  (SHA-256 `ca055e53a15268e5541102e58b5e08fda17b243327160ceabb54fcc76a2c9ade`,
  checked by `bootstrap/coverage.sh install`)
- Use: a CI tool only. It measures the line coverage of this repository's
  own scripts in the Bootstrapper workflow (PBI-1.41). It is downloaded
  and run there and never copied into this repository, into a project or
  into the bootstrapper.
- Copyright, from `LICENSE.txt` of bashcov 4.0.2:

      Copyright (c) 2012-2025 Cédric Félizard

## simplecov 1.3.2

- Licence: MIT
- Source: https://github.com/simplecov-ruby/simplecov, installed as the
  gem simplecov 1.3.2 from https://rubygems.org/downloads/simplecov-1.3.2.gem
  (SHA-256 `2a22ec1759f1b8db60881a2e038758956fc69ef93ed669be0bde0678de6d0e85`,
  checked by `bootstrap/coverage.sh install`)
- Use: a CI tool only, the library bashcov reports through, in the same
  workflow. It is downloaded and run there and never copied into this
  repository, into a project or into the bootstrapper. `.simplecov` is
  this repository's own configuration of it.
- Copyright, from `LICENSE` of simplecov 1.3.2:

      Copyright (c) 2010-2026 Erik Berlin, Benjamin Fleischer, Akira Matsuda, Christoph Olszowka, Tobias Pfeiffer, David Rodríguez, and Xavier Shay

## ShellCheck 0.11.0

- Licence: GPL-3.0. Allowed by Adam, 2026-11-06 20:02, as a CI and local
  tool only, never copied or shipped (the third-party record is on #378).
- Source: https://github.com/koalaman/shellcheck, tag v0.11.0 (`aac0823`),
  the official release archive
  https://github.com/koalaman/shellcheck/releases/download/v0.11.0/shellcheck-v0.11.0.linux.x86_64.tar.xz
  (SHA-256 `8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198`,
  checked by the lint step in `.github/workflows/ci.yml`)
- Use: a CI tool only. `build` lints this repository's own scripts with it
  (PBI-1.41). It is downloaded and run there, unmodified, and never copied
  into this repository, into a project or into the bootstrapper.
  `.shellcheckrc` is this repository's own configuration of it.
- Copyright, from `README.md` of ShellCheck v0.11.0 (its `LICENSE` holds
  the GPL-3.0 text):

      Copyright 2012-2019, Vidar 'koala_man' Holen and contributors.

## shfmt 3.14.1

- Licence: BSD-3-Clause
- Source: https://github.com/mvdan/sh, tag v3.14.1 (`a3f0c75`), the
  official release binary
  https://github.com/mvdan/sh/releases/download/v3.14.1/shfmt_v3.14.1_linux_amd64
  (SHA-256 `76e77641faa025814b77f153b29796b8e6fa2fca03e0c76a691608b86c7ea7bf`,
  checked by the format step in `.github/workflows/ci.yml`)
- Use: a CI tool only. `build` checks the format of this repository's own
  scripts with it (PBI-1.41). It is downloaded and run there and never
  copied into this repository, into a project or into the bootstrapper.
- Copyright, from `LICENSE` of mvdan/sh v3.14.1:

      Copyright (c) 2016, Daniel Martí. All rights reserved.
