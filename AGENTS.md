# NHANES.jl

Julia package for accessing CDC NHANES (National Health and Nutrition Examination Survey) data.

## Architecture

- `src/types.jl` - Exception types, constants
- `src/urls.jl` - URL construction and relative-link resolution
- `src/cache.jl` - Scratch.jl-based caching
- `src/http.jl` - HTTP fetch utilities
- `src/metadata.jl` - HTML parsing with Lexbor.jl
- `src/download.jl` - Core data download
- `src/tables.jl` - List available tables
- `src/variables.jl` - List variables in tables
- `src/codebook.jl` - Variable codebook access
- `src/translate.jl` - Value label translation
- `src/search.jl` - Variable search
- `src/dxa.jl` - DXA (bone density) data
- `src/historical.jl` - NHANES I/II/III listing and file access

## API surface

Only the exception types are exported. Everything else is reached through the
module (`NHANES.download`, `NHANES.tables`, ...) because `download`, `search`,
`tables` and `translate` collide with Base and with common packages.

## Testing

Uses TestItemRunner.jl. Run tests with:

```julia
using Pkg; Pkg.test("NHANES")
```

Tags: `:unit` (offline), `:integration` (network required). `test/runtests.jl`
skips `:integration` unless `NHANES_TEST_INTEGRATION=true`, and runs everything
else, so an untagged item still executes.

Parser tests run against trimmed CDC pages in `test/fixtures/`. Add a fixture
rather than a network test when covering markup handling.

## Formatting

Runic, via `just format`. CI runs the same recipe then `git diff --exit-code`.

## Data Sources

- Continuous NHANES (1999-present): `https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/`
- Historical surveys: NHANES I (1971-74), II (1976-80), III (1988-94)
- DXA data (1999-2006): bone density/body composition
