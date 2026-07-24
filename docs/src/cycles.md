```@meta
CurrentModule = NHANES
DocTestSetup = :(import NHANES)
```

# Survey cycles and table names

Continuous NHANES runs in two-year cycles. A table name is a base name plus a
cycle marker, so the same measurement carries a different name in each cycle:
demographics is `DEMO` for 1999-2000 and `DEMO_J` for 2017-2018.

| Years | Marker | Example |
|-------|--------|---------|
| 1999-2000 | (none) | `DEMO` |
| 2001-2002 | `_B` | `DEMO_B` |
| 2003-2004 | `_C` | `DEMO_C` |
| 2005-2006 | `_D` | `DEMO_D` |
| 2007-2008 | `_E` | `DEMO_E` |
| 2009-2010 | `_F` | `DEMO_F` |
| 2011-2012 | `_G` | `DEMO_G` |
| 2013-2014 | `_H` | `DEMO_H` |
| 2015-2016 | `_I` | `DEMO_I` |
| 2017-2018 | `_J` | `DEMO_J` |
| 2017-March 2020 | `P_` prefix | `P_DEMO` |
| 2021-2023 | `_L` | `DEMO_L` |

```jldoctest
julia> NHANES.survey_years()
11-element Vector{Int64}:
 1999
 2001
 2003
 2005
 2007
 2009
 2011
 2013
 2015
 2017
 2021
```

## Years and markers

[`NHANES.cycle_suffix`](@ref) maps a cycle start year to its marker, and
[`NHANES.suffix_to_year`](@ref) maps back. `suffix_to_year` accepts the marker
with or without its underscore.

```jldoctest
julia> NHANES.cycle_suffix(2017)
"_J"

julia> NHANES.cycle_suffix(1999)
""

julia> NHANES.suffix_to_year("_J")
2017

julia> NHANES.suffix_to_year("B")
2001
```

## The missing 2019-2020 cycle

COVID-19 cut the 2019-2020 collection short. CDC folded the partial data into
the 2017-March 2020 pre-pandemic files, which use a `P_` prefix rather than a
suffix, and skipped the letter `_K`, so 2021-2023 is `_L`. Asking for 2019 says
so.

```jldoctest
julia> NHANES.cycle_suffix(2019)
ERROR: ArgumentError: NHANES 2019-2020 was never released publicly: data collection was cut short by COVID-19 and the results were folded into the 2017-March 2020 pre-pandemic files. Use the pre-pandemic cycle :P instead.
```

Pass the symbol `:P` where a year is expected to reach the pre-pandemic cycle.

```julia
NHANES.tables(:Examination, :P)
NHANES.download("P_BMX")
```

## Splitting a table name

[`NHANES.parse_table_name`](@ref) separates the base name from the cycle marker.
A base name may itself contain underscores, so only a trailing single letter
that is a known marker counts as a suffix.

```jldoctest
julia> NHANES.parse_table_name("DEMO_J")
("DEMO", "_J")

julia> NHANES.parse_table_name("ALB_CR_J")
("ALB_CR", "_J")

julia> NHANES.parse_table_name("P_BMX")
("BMX", "P_")

julia> NHANES.parse_table_name("DEMO")
("DEMO", "")
```

## Components

Five components partition the survey. Each accepts its full name or its R-style
short name, in any case.

```jldoctest
julia> NHANES.COMPONENTS
(:Demographics, :Dietary, :Examination, :Laboratory, :Questionnaire)

julia> NHANES.normalize_component(:LAB)
:Laboratory

julia> NHANES.normalize_component(:demographics)
:Demographics
```

## URLs

The URL for a table follows from its marker: the cycle start year names the
directory, and pre-pandemic tables live in the 2017 directory alongside the
2017-2018 files.

```jldoctest
julia> NHANES.table_url("DEMO_J")
"https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DEMO_J.xpt"

julia> NHANES.table_url("P_BMX")
"https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_BMX.xpt"

julia> NHANES.codebook_url("BMX_D")
"https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2005/DataFiles/BMX_D.htm"

julia> NHANES.variablelist_url(:Laboratory, 2015)
"https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=Laboratory&CycleBeginYear=2015"

julia> NHANES.variablelist_url(:Examination, :P)
"https://wwwn.cdc.gov/nchs/nhanes/search/variablelist.aspx?Component=Examination&Cycle=2017-2020"
```

Listing pages link to their data files relatively, so
[`NHANES.resolve_url`](@ref) resolves a link against the page it came from.

```jldoctest
julia> NHANES.resolve_url(
           "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/datafiles.aspx",
           "../../data/nhanes3/1a/adult.dat",
       )
"https://wwwn.cdc.gov/nchs/data/nhanes3/1a/adult.dat"
```

## DXA cycles

Dual energy X-ray absorptiometry data covers four cycles and sits outside the
component listings, so [`NHANES.dxa_tables`](@ref) builds its names and URLs
directly.

```jldoctest
julia> NHANES.DXA_YEARS
(1999, 2001, 2003, 2005)

julia> NHANES.dxa_tables(2005).name
1-element Vector{String}:
 "DXX_D"

julia> NHANES.dxa_tables(2005; suppl = true).url
1-element Vector{String}:
 "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2005/DataFiles/dxx_d_s.xpt"
```

Downloading the data itself needs the network.

```julia
NHANES.dxa(2005)
NHANES.dxa(2005; suppl = true)
```

## Historical surveys

The three surveys that predate continuous NHANES are named rather than dated.

```jldoctest
julia> NHANES.HISTORICAL_SURVEYS
(:nhanes1, :nhanes2, :nhanes3)
```

Their listings carry an absolute `url` per file, since the names do not follow
the continuous cycle scheme.

```julia
NHANES.historical_tables(:nhanes3)
df = NHANES.historical_download(:nhanes3, "SSNH3MGM")
path = NHANES.historical_file(:nhanes1, "DU4111")
```

NHANES III publishes SAS transport files, which read like continuous NHANES.
NHANES I and II publish fixed-width text, which needs the column layouts from
CDC's SAS input statements, so `historical_file` hands back a path to parse
rather than a `DataFrame`.
