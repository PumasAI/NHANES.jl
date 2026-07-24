```@meta
CurrentModule = NHANES
DocTestSetup = :(import NHANES)
```

# NHANES.jl

Access CDC NHANES (National Health and Nutrition Examination Survey) data from
Julia: download data tables, list what a cycle publishes, read codebooks, and
translate coded values to their labels.

```@docs
NHANES
```

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/PumasAI/NHANES.jl")
```

## Nothing is exported

Reach every entry point through the module. `download`, `search`, `tables` and
`translate` are names Base and other packages use too, so exporting them would
make the package unsafe to combine.

```julia
import NHANES

demo = NHANES.download("DEMO_J")
```

## Quick start

Each call below fetches from `wwwn.cdc.gov`. The documentation build does not
run them, so the results are described rather than shown.

```julia
import NHANES

demo = NHANES.download("DEMO_J")        # 2017-2018 demographics, as a DataFrame
NHANES.tables(:Laboratory, 2015)        # laboratory tables published for 2015-2016
NHANES.variables("DEMO_J")              # variable names and labels in a table
NHANES.codebook("DEMO_J", :RIAGENDR)    # codes, labels and counts for one variable
NHANES.search("blood pressure")         # variables whose description matches
```

The [Guide](@ref) covers each of these in turn. [Survey cycles and table
names](@ref) explains how a year maps onto a table name, and the
[API reference](@ref) lists the full call surface.

## Errors

Every failure raises a subtype of [`NHANES.NHANESError`](@ref).

```jldoctest
julia> err = NHANES.TableNotFoundError("DEMO_X", "Table not found: DEMO_X")
NHANES.TableNotFoundError("DEMO_X", "Table not found: DEMO_X")

julia> err isa NHANES.NHANESError
true

julia> sprint(showerror, err)
"TableNotFoundError: Table not found: DEMO_X"
```

`DownloadError` carries the HTTP status when there was one.

```jldoctest
julia> sprint(showerror, NHANES.DownloadError("https://wwwn.cdc.gov/x.xpt", "Failed to download", 503))
"DownloadError: Failed to download (HTTP 503)"

julia> sprint(showerror, NHANES.MetadataError("codebook", "No value tables found"))
"MetadataError: No value tables found (source: codebook)"
```

CDC answers 404 for an unknown table name, which surfaces as
`TableNotFoundError`. Connection failures, 429 and 5xx are retried with
exponential backoff before surfacing as `DownloadError`. Other 4xx responses are
not retried.

Table names are checked before they reach a URL or a cache path.

```jldoctest
julia> NHANES.table_url("../../etc/passwd")
ERROR: ArgumentError: Invalid table name: "../../etc/passwd". Only letters, digits and underscores are allowed.
```
