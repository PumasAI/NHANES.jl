"""
    _get_cached_variablelist(component::Symbol, year::Union{Int,Symbol};
                             force::Bool=false) -> Vector{Dict}

Get variable list for a component/year, using cache if available.
"""
function _get_cached_variablelist(
        component::Symbol,
        year::Union{Int, Symbol};
        force::Bool = false,
    )
    cache_key = "$(component)_$(year)"

    if !force
        cached = load_metadata("variablelist", cache_key)
        if cached !== nothing
            return cached
        end
    end

    url = variablelist_url(component, year)
    html = fetch_html(url)
    vars = parse_variablelist_html(html)

    save_metadata("variablelist", cache_key, vars)

    return vars
end

"""
    _skip_missing(f)

Run `f`, returning `nothing` when CDC publishes no page for the request.
Every other failure propagates, so a network outage or a markup change is not
mistaken for an empty result.
"""
function _skip_missing(f)
    try
        return f()
    catch e
        e isa DownloadError && e.status == 404 && return nothing
        rethrow()
    end
end

"""All cycles to search by default (regular years + pre-pandemic)."""
function _all_cycles()
    cycles = Union{Int, Symbol}[survey_years()...]
    push!(cycles, PREPANDEMIC_CYCLE)
    return cycles
end

"""
Number of CDC page fetches allowed in flight at once. Six matches the per-host
connection limit browsers use, so a search asks no more of wwwn.cdc.gov than
loading the same pages in a browser would, and measured throughput stops
improving beyond it.
"""
const SEARCH_CONCURRENCY = 6

"""
    _search_components(component::Union{Symbol,Nothing}) -> Vector{Symbol}

Components a search covers: every component, or just the one requested.
"""
function _search_components(component::Union{Symbol, Nothing})
    component === nothing && return collect(COMPONENTS)
    return [normalize_component(component)]
end

"""
    _search_cycles(years::Union{Int,AbstractRange,Nothing}) -> Vector{Union{Int,Symbol}}

Cycles a search covers, in survey order, dropping years CDC has not published.
"""
function _search_cycles(years::Union{Int, AbstractRange, Nothing})
    cycles = if years === nothing
        _all_cycles()
    elseif years isa Int
        Union{Int, Symbol}[years]
    else
        Union{Int, Symbol}[collect(years)...]
    end
    return filter(
        y -> y === PREPANDEMIC_CYCLE || haskey(SURVEY_CYCLES, y),
        cycles,
    )
end

"""
    _fetch_pages(f, components, cycles) -> Vector{Tuple}

Apply `f(component, cycle)` to every pair, keeping up to `SEARCH_CONCURRENCY`
fetches in flight, and return `(component, cycle, result)` triples in
`components` by `cycles` order however the fetches interleave. Pairs CDC does
not publish are dropped, as in [`_skip_missing`](@ref). A failure surfaces with
its original type once the fetches in flight settle, and stops the remaining
pairs from being fetched.
"""
function _fetch_pages(f, components, cycles)
    requests = [(comp, cycle) for comp in components for cycle in cycles]
    failed = Ref(false)

    # Failures come back as values because asyncmap wraps a thrown exception in
    # a CapturedException, which would defeat `catch e; e isa DownloadError`.
    outcomes = asyncmap(requests; ntasks = SEARCH_CONCURRENCY) do (comp, cycle)
        failed[] && return nothing
        try
            _skip_missing(() -> f(comp, cycle))
        catch e
            failed[] = true
            e
        end
    end

    pages = Tuple{Symbol, Union{Int, Symbol}, Any}[]
    for ((comp, cycle), outcome) in zip(requests, outcomes)
        outcome isa Exception && throw(outcome)
        outcome === nothing && continue
        push!(pages, (comp, cycle, outcome))
    end
    return pages
end

"""
    search(pattern::AbstractString; component::Union{Symbol,Nothing}=nothing,
           years::Union{Int,AbstractRange,Nothing}=nothing,
           force::Bool=false) -> DataFrame

Search for variables matching a pattern across NHANES tables.

Each component and cycle needs one variable list page from CDC, and those pages
run to several hundred kilobytes. An unfiltered search fetches one per
combination, around 60 pages, `SEARCH_CONCURRENCY` at a time. Results are
cached, so later calls are fast. Narrow the search with `component` and `years`
to fetch fewer pages.

# Arguments
- `pattern::AbstractString`: Regex pattern to match variable names or descriptions
- `component::Union{Symbol,Nothing}=nothing`: Filter to specific component
- `years::Union{Int,AbstractRange,Nothing}=nothing`: Filter to specific survey cycles
- `force::Bool=false`: Force refresh from CDC (ignore cached variable lists)

# Returns
- `DataFrame`: Matching variables with columns:
  - `variable`: Variable name
  - `description`: Variable description
  - `table`: Table containing the variable
  - `component`: Component type
  - `cycle`: Survey cycle start year, or `:P` for pre-pandemic

# Examples
```julia
# Search for blood pressure variables
NHANES.search("blood pressure")

# Search in Laboratory component only
NHANES.search("glucose"; component=:Laboratory)

# Search in specific years
NHANES.search("BMI"; years=2015:2018)
```

# See Also
- [`variables`](@ref): List variables in a specific table
- [`tables`](@ref): List available tables
"""
function search(
        pattern::AbstractString;
        component::Union{Symbol, Nothing} = nothing,
        years::Union{Int, AbstractRange, Nothing} = nothing,
        force::Bool = false,
    )
    rx = Regex(pattern, "i")
    results = Dict{String, Any}[]

    pages = _fetch_pages(
        _search_components(component),
        _search_cycles(years),
    ) do comp, cycle
        _get_cached_variablelist(comp, cycle; force)
    end

    for (comp, cycle, vars) in pages
        for var in vars
            name = get(var, "name", "")
            desc = get(var, "description", "")
            tbl = get(var, "table", "")

            if occursin(rx, name) || occursin(rx, desc)
                push!(
                    results,
                    Dict(
                        "variable" => name,
                        "description" => desc,
                        "table" => tbl,
                        "component" => String(comp),
                        "cycle" => cycle,
                    ),
                )
            end
        end
    end

    return _search_results_to_dataframe(results)
end

"""
    _search_results_to_dataframe(results::Vector) -> DataFrame

Convert search results to a DataFrame.
"""
function _search_results_to_dataframe(results::Vector)
    if isempty(results)
        return DataFrames.DataFrame(
            variable = String[],
            description = String[],
            table = String[],
            component = String[],
            cycle = Union{Int, Symbol}[],
        )
    end

    return DataFrames.DataFrame(
        variable = [r["variable"] for r in results],
        description = [r["description"] for r in results],
        table = [r["table"] for r in results],
        component = [r["component"] for r in results],
        cycle = [r["cycle"] for r in results],
    )
end

"""
    search_var_name(varname::AbstractString;
                    years::Union{Int,AbstractRange,Nothing}=nothing,
                    force::Bool=false) -> DataFrame

Search for a specific variable name across all NHANES tables.

Searches every component, so the same fetching cost as [`search`](@ref)
applies.

# Arguments
- `varname::AbstractString`: Exact variable name to search for (case-insensitive)
- `years::Union{Int,AbstractRange,Nothing}=nothing`: Filter to specific survey cycles
- `force::Bool=false`: Force refresh from CDC (ignore cached variable lists)

# Returns
- `DataFrame`: Tables containing the variable with columns:
  - `variable`: Variable name
  - `table`: Table name
  - `component`: Component type
  - `cycle`: Survey cycle start year, or `:P` for pre-pandemic

# Examples
```julia
# Find all tables containing BMXLEG variable
NHANES.search_var_name("BMXLEG")

# Search in specific years
NHANES.search_var_name("BPXPULS"; years=2005:2010)
```

# See Also
- [`search`](@ref): Search by pattern in names and descriptions
- [`search_table_names`](@ref): Search table names by pattern
"""
function search_var_name(
        varname::AbstractString;
        years::Union{Int, AbstractRange, Nothing} = nothing,
        force::Bool = false,
    )
    varname_upper = uppercase(varname)
    results = Dict{String, Any}[]

    pages = _fetch_pages(COMPONENTS, _search_cycles(years)) do comp, cycle
        _get_cached_variablelist(comp, cycle; force)
    end

    for (comp, cycle, vars) in pages
        for var in vars
            name = get(var, "name", "")
            if uppercase(name) == varname_upper
                push!(
                    results,
                    Dict(
                        "variable" => name,
                        "table" => get(var, "table", ""),
                        "component" => String(comp),
                        "cycle" => cycle,
                    ),
                )
            end
        end
    end

    return _varname_results_to_dataframe(results)
end

function _varname_results_to_dataframe(results::Vector)
    if isempty(results)
        return DataFrames.DataFrame(
            variable = String[],
            table = String[],
            component = String[],
            cycle = Union{Int, Symbol}[],
        )
    end

    return DataFrames.DataFrame(
        variable = [r["variable"] for r in results],
        table = [r["table"] for r in results],
        component = [r["component"] for r in results],
        cycle = [r["cycle"] for r in results],
    )
end

"""
    search_table_names(pattern::AbstractString;
                       component::Union{Symbol,Nothing}=nothing,
                       years::Union{Int,AbstractRange,Nothing}=nothing,
                       force::Bool=false) -> DataFrame

Search for tables by name pattern.

Table lists come from the same CDC pages as [`search`](@ref), so the same
fetching cost applies.

# Arguments
- `pattern::AbstractString`: Regex pattern to match table names
- `component::Union{Symbol,Nothing}=nothing`: Filter to specific component
- `years::Union{Int,AbstractRange,Nothing}=nothing`: Filter to specific survey cycles
- `force::Bool=false`: Force refresh from CDC (ignore cached table lists)

# Returns
- `DataFrame`: Matching tables with columns:
  - `name`: Table name
  - `description`: Table description
  - `component`: Component type
  - `cycle`: Survey cycle start year, or `:P` for pre-pandemic

# Examples
```julia
# Find all BMX tables
NHANES.search_table_names("BMX")

# Find tables in Laboratory component
NHANES.search_table_names("GLU"; component=:Laboratory)
```

# See Also
- [`search`](@ref): Search variables by pattern
- [`search_var_name`](@ref): Search by exact variable name
- [`tables`](@ref): List tables for a component/year
"""
function search_table_names(
        pattern::AbstractString;
        component::Union{Symbol, Nothing} = nothing,
        years::Union{Int, AbstractRange, Nothing} = nothing,
        force::Bool = false,
    )
    rx = Regex(pattern, "i")
    results = Dict{String, Any}[]
    seen = Set{String}()

    pages = _fetch_pages(
        _search_components(component),
        _search_cycles(years),
    ) do comp, cycle
        tables(comp, cycle; force)
    end

    for (comp, cycle, tbls) in pages
        for row in eachrow(tbls)
            name = row.name
            if occursin(rx, name) && !(name in seen)
                push!(seen, name)
                push!(
                    results,
                    Dict(
                        "name" => name,
                        "description" => row.description,
                        "component" => String(comp),
                        "cycle" => cycle,
                    ),
                )
            end
        end
    end

    return _tablename_results_to_dataframe(results)
end

function _tablename_results_to_dataframe(results::Vector)
    if isempty(results)
        return DataFrames.DataFrame(
            name = String[],
            description = String[],
            component = String[],
            cycle = Union{Int, Symbol}[],
        )
    end

    return DataFrames.DataFrame(
        name = [r["name"] for r in results],
        description = [r["description"] for r in results],
        component = [r["component"] for r in results],
        cycle = [r["cycle"] for r in results],
    )
end
