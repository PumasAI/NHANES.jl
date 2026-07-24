# Changelog

All notable changes to NHANES.jl are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

## v0.1.0 - 2026-07-24

First release.

### Added

- `download` for continuous NHANES tables, returning a `DataFrame`. Categorical
  variables are translated to their labels; continuous variables stay numeric.
- `tables` and `variables` for listing what a component, cycle or table
  publishes, including the 2017-March 2020 pre-pandemic `P_` cycle.
- `codebook` reporting published codes, labels and counts from the data.
- `translate` and `translate!` for translating chosen columns.
- `search`, `search_var_name` and `search_table_names` across components and
  cycles, fetched six pages at a time.
- `dxa` and `dxa_tables` for the 1999-2006 bone density and body composition
  data.
- `historical_tables`, `historical_download` and `historical_file` for
  NHANES I, II and III.
- `clear_cache`. Data files are cached permanently, scraped metadata for 30
  days.
- `NHANESError` and its subtypes `TableNotFoundError`, `DownloadError` and
  `MetadataError`.
