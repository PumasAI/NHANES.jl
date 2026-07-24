"""
    NHANES

Julia package for accessing CDC NHANES (National Health and Nutrition
Examination Survey) data.

Nothing is exported. Reach everything through the module.

# Quick Start

```julia
import NHANES

demo = NHANES.download("DEMO_J")
NHANES.tables(:Laboratory, 2017)
NHANES.search("blood pressure")
```
"""
module NHANES

import DataFrames
import JSON
import Lexbor
import ReadStatTables
import Scratch

include("types.jl")
include("urls.jl")
include("cache.jl")
include("http.jl")
include("download.jl")
include("metadata.jl")
include("tables.jl")
include("variables.jl")
include("codebook.jl")
include("translate.jl")
include("search.jl")
include("dxa.jl")
include("historical.jl")

end
