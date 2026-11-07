# simplecov's configuration for the line coverage of the template's own
# scripts (PBI-1.41 c2): bootstrap/coverage.sh run starts bashcov from the
# root, and simplecov reads this file there. Template-only: it is not in
# bootstrap/manifest.txt.
#
# simplecov's default filters leave out files in folders whose names start
# with a dot (.github/scripts/) and files outside the root (the copies of
# the scripts that the tests run), so none is kept: coverage.sh keeps the
# counted scripts and maps each copy onto its script. The result set goes
# where coverage.sh says, outside the checkout, and no report is written.
SimpleCov.filters.clear
SimpleCov.coverage_dir(ENV["BOOTSTRAP_COVERAGE_DIR"]) if ENV["BOOTSTRAP_COVERAGE_DIR"]
SimpleCov.formatter SimpleCov::Formatter::SimpleFormatter
