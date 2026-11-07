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
