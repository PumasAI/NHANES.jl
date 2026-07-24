# NHANES.jl

Julia package for accessing CDC NHANES (National Health and Nutrition Examination Survey) data.

## Installation

```julia
using Pkg
Pkg.add(url="https://github.com/PumasAI/NHANES.jl")
```

## Quick Start

```julia
import NHANES

# Download 2017-2018 Demographics
demo = NHANES.download("DEMO_J")

# List available laboratory tables
NHANES.tables(:Laboratory, 2017)

# Search for blood pressure variables
NHANES.search("blood pressure")
```

Nothing is exported. Reach everything through the module, as above.
`download`, `search`, `tables` and `translate` are names Base and other
packages use too, so exporting them would make the package unsafe to combine.

## API

### Data Access

```julia
# Download a table as DataFrame (translates coded values by default)
df = NHANES.download("DEMO_J")
df = NHANES.download("DEMO_J"; translate=false)  # Keep numeric codes

# List tables for a component and year
NHANES.tables(:Demographics, 2017)
NHANES.tables(:Laboratory, 2015)
NHANES.tables(:Examination, 2013)

# Components: :Demographics, :Dietary, :Examination, :Laboratory, :Questionnaire
```

### Metadata

```julia
# List variables in a table
NHANES.variables("DEMO_J")

# Get codebook for a variable
NHANES.codebook("DEMO_J", :RIAGENDR)
# 3×3 DataFrame
#  Row │ code    label    count
#      │ String  String   Int64
# ─────┼────────────────────────
#    1 │ 1       Male      4557
#    2 │ 2       Female    4697
#    3 │ .       Missing      0
```

`code` is a `String` holding the code exactly as CDC publishes it, so a
continuous variable reports its range rather than one row per observed value:

```julia
NHANES.codebook("BMX_J", :BMXWT)
# 2×3 DataFrame
#  Row │ code          label            count
#      │ String        String           Int64
# ─────┼──────────────────────────────────────
#    1 │ 3.2 to 242.6  Range of Values   8580
#    2 │ .             Missing            124
```

### Value Translation

`download` translates categorical variables to their labels and leaves
continuous variables numeric. `RIAGENDR` comes back as "Male"/"Female" while
`RIDAGEYR` and the survey weight `WTMEC2YR` stay `Float64`.

Reserved codes on a continuous variable (7 or 7777 for "Refused", 9 or 9999 for
"Don't know", and similar) stay numeric along with the rest of the column, so
they are included in an unguarded `mean`. Call `codebook` to see which codes a
variable reserves, and filter them before summarising. R's `nhanesA` instead
converts such columns to character, which is what made the numeric columns
unusable here.

```julia
# Download without translation to get numeric codes
demo = NHANES.download("DEMO_J"; translate=false)

# Translate specific column in-place
NHANES.translate!(demo, "DEMO_J", :RIAGENDR)

# Translate multiple columns
NHANES.translate!(demo, "DEMO_J", [:RIAGENDR, :RIDRETH1])

# Non-mutating translation
demo_labeled = NHANES.translate(demo, "DEMO_J", :RIAGENDR)
```

### Search

```julia
# Search variable descriptions
NHANES.search("glucose")
NHANES.search("cholesterol"; component=:Laboratory)
NHANES.search("BMI"; years=2015:2018)

# Search by exact variable name
NHANES.search_var_name("BMXLEG")
NHANES.search_var_name("BPXPULS"; years=2005:2010)

# Search table names
NHANES.search_table_names("BMX")
NHANES.search_table_names("GLU"; component=:Laboratory)

# Refresh a cached variable list
NHANES.search("glucose"; force=true)
```

An unfiltered search fetches one variable list per component and cycle, around
60 pages of several hundred kilobytes each. Pages are fetched six at a time, so
a cold call takes roughly ten seconds and later calls read the 30-day cache.
Narrow with `component` or `years` to cut the cost.

### DXA Data

Dual Energy X-Ray Absorptiometry data (bone density/body composition) available for 1999-2006.

```julia
NHANES.dxa_tables(2005)  # List available DXA tables
dxa_data = NHANES.dxa(2005)  # Download DXA data

# Supplemental data (highly variable imputation)
NHANES.dxa(2005; suppl=true)
```

Note: DXA datasets contain 5 imputation sets per participant. Analyze all 5 separately - do not average.

### Historical Surveys

List the data files published for the pre-continuous surveys.

```julia
NHANES.historical_tables(:nhanes1)  # 1971-1975
NHANES.historical_tables(:nhanes2)  # 1976-1980
NHANES.historical_tables(:nhanes3)  # 1988-1994
```

Each row carries a `name`, a `description` and an absolute `url`.

NHANES III publishes SAS transport files, which read like continuous NHANES:

```julia
df = NHANES.historical_download(:nhanes3, "SSNH3MGM")
```

NHANES I and II publish fixed-width text. Reading those needs the column
layouts from CDC's SAS input statements, which this package does not parse, so
`historical_file` downloads the file and returns its path for you to parse:

```julia
path = NHANES.historical_file(:nhanes1, "DU4111")
```

`historical_download` rejects a fixed-width file rather than guessing at its
layout. `historical_file` accepts any listed file, transport files included.

## Survey Cycles

Continuous NHANES uses 2-year cycles with letter suffixes:

| Years | Suffix | Example |
|-------|--------|---------|
| 1999-2000 | (none) | DEMO |
| 2001-2002 | _B | DEMO_B |
| 2003-2004 | _C | DEMO_C |
| ... | ... | ... |
| 2017-2018 | _J | DEMO_J |
| 2021-2023 | _L | DEMO_L |

There is no 2019-2020 cycle. Collection was cut short by COVID-19 and the
partial data was released as the 2017-March 2020 pre-pandemic files, which use
a `P_` prefix instead of a suffix. CDC skipped the letter `_K`, which is why
2021-2023 is `_L`.

```julia
NHANES.tables(:Examination, :P)  # pre-pandemic cycle
NHANES.download("P_BMX")
```

Note: Some tables listed in metadata are "RDC Only" (Research Data Center restricted) and cannot be downloaded publicly.

## Caching

Downloaded data is cached in `~/.julia/scratchspaces/`. XPT files are cached permanently (NHANES data is immutable). Metadata caches expire after 30 days.

```julia
NHANES.clear_cache()  # Clear all cached data
```

## Comparison with R nhanesA

| R (nhanesA) | Julia (NHANES.jl) |
|-------------|-------------------|
| `nhanes("DEMO_J")` | `NHANES.download("DEMO_J")` |
| `nhanes("DEMO_J", translate=FALSE)` | `NHANES.download("DEMO_J"; translate=false)` |
| `nhanesTables("EXAM", 2005)` | `NHANES.tables(:EXAM, 2005)` |
| `nhanesTableVars("EXAM", "BMX_D")` | `NHANES.variables("BMX_D")` |
| `nhanesCodebook("DEMO_D", "RIAGENDR")` | `NHANES.codebook("DEMO_D", :RIAGENDR)` |
| `nhanesTranslate("BPX_D", "BPXSY1", data=df)` | `NHANES.translate!(df, "BPX_D", :BPXSY1)` |
| `nhanesSearch("glucose")` | `NHANES.search("glucose")` |
| `nhanesSearchVarName("BMXLEG")` | `NHANES.search_var_name("BMXLEG")` |
| `nhanesSearchTableNames("BMX")` | `NHANES.search_table_names("BMX")` |
| `nhanesDXA(2005)` | `NHANES.dxa(2005)` |
| `nhanesDXA(2005, suppl=TRUE)` | `NHANES.dxa(2005; suppl=true)` |

Both packages translate coded values by default, but they disagree on
continuous variables: `nhanesA` converts a column to character as soon as the
codebook reserves any code, while NHANES.jl leaves it numeric. See
[Value Translation](#value-translation).

Component aliases supported:
- `:DEMO` or `:Demographics`
- `:DIET` or `:Dietary`
- `:EXAM` or `:Examination`
- `:LAB` or `:Laboratory`
- `:Q` or `:Questionnaire`

## Error Handling

```julia
try
    NHANES.download("INVALID_TABLE")
catch e
    if e isa NHANES.TableNotFoundError
        # CDC returned 404 for this table name
    elseif e isa NHANES.DownloadError
        # Network failure, or any other HTTP status
    elseif e isa NHANES.MetadataError
        # Codebook or variable list could not be parsed
    end
end
```

`TableNotFoundError` is raised when CDC answers 404, which is what an unknown
table name produces. Connection failures, 429 and 5xx are retried with
exponential backoff before surfacing as `DownloadError`; 4xx is not retried.
