# NHANES.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://PumasAI.github.io/NHANES.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://PumasAI.github.io/NHANES.jl/dev/)
[![CI](https://github.com/PumasAI/NHANES.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/PumasAI/NHANES.jl/actions/workflows/CI.yml)

Access CDC NHANES (National Health and Nutrition Examination Survey) data from
Julia. Download survey tables as `DataFrame`s, list what a cycle publishes, read
codebooks, translate coded values, and search variables across cycles.

## Installation

```julia
using Pkg
Pkg.add(url = "https://github.com/PumasAI/NHANES.jl")
```

## Usage

Nothing is exported. `download`, `search`, `tables` and `translate` are names
Base and other packages use too, so reach everything through the module.

```julia
import NHANES

demo = NHANES.download("DEMO_J")        # 2017-2018 demographics
NHANES.tables(:Laboratory, 2015)        # laboratory tables for 2015-2016
NHANES.variables("DEMO_J")              # variable names and labels
NHANES.codebook("DEMO_J", :RIAGENDR)    # codes, labels and counts
NHANES.search("blood pressure")         # variables matching a description
```

Categorical variables are translated to their labels by default and continuous
variables are left numeric, which is where this differs from R's `nhanesA`.

## Documentation

The documentation covers downloads, metadata, translation, search, DXA and the
historical surveys, along with how survey cycles map onto table names and what
to expect coming from `nhanesA`.

- [Stable](https://PumasAI.github.io/NHANES.jl/stable/) documents the most
  recent tagged release.
- [Dev](https://PumasAI.github.io/NHANES.jl/dev/) tracks `main`.

## License

MIT. See [LICENSE](LICENSE).
