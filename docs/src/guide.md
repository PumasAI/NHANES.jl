```@meta
CurrentModule = NHANES
DocTestSetup = :(import NHANES)
```

# Guide

Every call on this page fetches from `wwwn.cdc.gov`. The documentation build
does not run them, so results are described rather than shown.

## Downloading data

`download` takes a table name and returns a `DataFrame`.

```julia
df = NHANES.download("DEMO_J")                      # translated, cached
df = NHANES.download("DEMO_J"; translate = false)   # numeric codes
df = NHANES.download("DEMO_J"; force = true)        # ignore the cache
```

An unknown name raises [`NHANES.TableNotFoundError`](@ref), because CDC answers
404 for one. See [Survey cycles and table names](@ref) for how a year and a
component map onto a name.

## Listing tables and variables

```julia
NHANES.tables(:Demographics, 2017)   # tables published for 2017-2018
NHANES.tables(:Examination, :P)      # the 2017-March 2020 pre-pandemic cycle
NHANES.variables("DEMO_J")           # variable names and labels in one table
```

Components are `:Demographics`, `:Dietary`, `:Examination`, `:Laboratory` and
`:Questionnaire`. The R-style short forms `:DEMO`, `:DIET`, `:EXAM`, `:LAB` and
`:Q` work too, in any case.

Some tables a listing reports are marked "RDC Only", meaning access is
restricted to a Research Data Center. Those cannot be downloaded.

## Codebooks

`codebook` reports the codes CDC publishes for a variable, with counts taken
from the data.

```julia
NHANES.codebook("DEMO_J", :RIAGENDR)
# 3×3 DataFrame
#  Row │ code    label    count
#      │ String  String   Int64
# ─────┼────────────────────────
#    1 │ 1       Male      4557
#    2 │ 2       Female    4697
#    3 │ .       Missing      0
```

`code` is a `String` carrying the code exactly as published, so a continuous
variable reports its range rather than one row per observed value.

```julia
NHANES.codebook("BMX_J", :BMXWT)
# 2×3 DataFrame
#  Row │ code          label            count
#      │ String        String           Int64
# ─────┼──────────────────────────────────────
#    1 │ 3.2 to 242.6  Range of Values   8580
#    2 │ .             Missing            124
```

## Value translation

`download` translates categorical variables to their labels and leaves
continuous variables numeric. `RIAGENDR` comes back as "Male" or "Female",
while `RIDAGEYR` and the survey weight `WTMEC2YR` stay `Float64`.

Reserved codes on a continuous variable (7 or 7777 for "Refused", 9 or 9999 for
"Don't know", and similar) stay numeric with the rest of the column, so an
unguarded `mean` includes them. Call `codebook` to see which codes a variable
reserves, and filter them before summarising.

```julia
demo = NHANES.download("DEMO_J"; translate = false)
NHANES.translate!(demo, "DEMO_J", :RIAGENDR)
NHANES.translate!(demo, "DEMO_J", [:RIAGENDR, :RIDRETH1])

labelled = NHANES.translate(demo, "DEMO_J", :RIAGENDR)   # leaves demo alone
```

Translating a continuous variable raises `ArgumentError` rather than producing
a column of stringified numbers.

## Searching

```julia
NHANES.search("glucose")
NHANES.search("cholesterol"; component = :Laboratory)
NHANES.search("BMI"; years = 2015:2018)

NHANES.search_var_name("BMXLEG")            # exact variable name
NHANES.search_table_names("BMX")            # table name pattern

NHANES.search("glucose"; force = true)      # refresh the cached lists
```

An unfiltered search covers every component and cycle, about 60 pages. They are
fetched six at a time, so a cold call takes roughly ten seconds; later calls
read the 30-day metadata cache and return in a fraction of a second. Narrowing
with `component` or `years` cuts the first call down.

## DXA

Dual-energy X-ray absorptiometry data covers 1999-2006 and is published apart
from the main tables.

```julia
NHANES.dxa_tables(2005)
NHANES.dxa(2005)
NHANES.dxa(2005; suppl = true)   # highly variable imputation data
```

Each DXA dataset carries five imputation sets per participant. Analyse the five
separately. Averaging them understates the variance the imputation exists to
represent.

## Historical surveys

The surveys before continuous NHANES publish files rather than the tables
`download` reads.

```julia
NHANES.historical_tables(:nhanes1)   # 1971-1975
NHANES.historical_tables(:nhanes2)   # 1976-1980
NHANES.historical_tables(:nhanes3)   # 1988-1994
```

Each row carries a `name`, a `description` and an absolute `url`. NHANES III
publishes SAS transport files, which read like continuous NHANES:

```julia
df = NHANES.historical_download(:nhanes3, "SSNH3MGM")
```

NHANES I and II publish fixed-width text. Reading it needs the column layout
from the SAS input statement CDC ships beside the data, which this package does
not carry, so `historical_file` downloads the file and hands back its path:

```julia
path = NHANES.historical_file(:nhanes1, "DU4111")
```

`historical_download` rejects a fixed-width file rather than guessing at its
layout. `historical_file` accepts anything a listing reports, transport files
included.

## Caching

XPT files are cached permanently, since published NHANES data does not change.
Scraped metadata expires after 30 days. Both live under
`~/.julia/scratchspaces/`.

```julia
NHANES.clear_cache()
```
