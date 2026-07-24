"""
    tables(component::Symbol, year::Union{Int,Symbol}; force::Bool=false) -> DataFrame

List available data tables for a component and survey cycle.

# Arguments
- `component::Symbol`: One of :Demographics, :Dietary, :Examination, :Laboratory, :Questionnaire
- `year::Union{Int,Symbol}`: Start year of the survey cycle (e.g., 2017), or :P for pre-pandemic
- `force::Bool=false`: Force refresh from CDC (ignore cache)

# Returns
- `DataFrame`: Available tables with columns:
  - `name`: Table name (e.g., "DEMO_J", "P_BMX")
  - `description`: Table description

# Examples
```julia
# List all laboratory tables for 2017-2018
NHANES.tables(:Laboratory, 2017)

# List demographics tables for 2015-2016
NHANES.tables(:Demographics, 2015)

# List pre-pandemic examination tables (2017-March 2020)
NHANES.tables(:Examination, :P)
```

# See Also
- [`download`](@ref): Download a specific table
- [`variables`](@ref): List variables in a table
"""
function tables(component::Symbol, year::Union{Int, Symbol}; force::Bool = false)
    component = normalize_component(component)

    if year isa Int
        haskey(SURVEY_CYCLES, year) || throw(
            ArgumentError(
                "Invalid survey cycle year: $year. Must be an odd year >= 1999 (e.g., 1999, 2001, 2003, ...)",
            ),
        )
    elseif year !== PREPANDEMIC_CYCLE
        throw(
            ArgumentError(
                "Invalid cycle: $year. Use an Int year or :P for pre-pandemic",
            ),
        )
    end

    cache_key = "$(component)_$(year)"
    if !force
        cached = load_metadata("tables", cache_key)
        if cached !== nothing
            return _tables_to_dataframe(cached)
        end
    end

    url = variablelist_url(component, year)
    html = fetch_html(url)

    # The variable list page contains table names in the "Data File Name" column
    tables_data = _parse_tables_from_variablelist(html)

    save_metadata("tables", cache_key, tables_data)

    return _tables_to_dataframe(tables_data)
end

"""
    _parse_tables_from_variablelist(html::AbstractString) -> Vector{Dict}

Extract unique table information from a variable list page.
Each variable on the page names the data file it belongs to.
"""
function _parse_tables_from_variablelist(html::AbstractString)
    tables_seen = Set{String}()
    tables_data = Dict{String, Any}[]

    for var in parse_variablelist_html(html)
        table_name = get(var, "table", "")
        isempty(table_name) && continue
        table_name in tables_seen && continue

        push!(tables_seen, table_name)
        push!(
            tables_data,
            Dict(
                "name" => table_name,
                "description" => get(var, "table_description", ""),
            ),
        )
    end

    return tables_data
end

"""
    _tables_to_dataframe(data::Vector) -> DataFrame

Convert parsed tables data to a DataFrame.
Includes URL column if present in data.
"""
function _tables_to_dataframe(data::Vector)
    if isempty(data)
        return DataFrames.DataFrame(name = String[], description = String[])
    end

    names = [d["name"] for d in data]
    descriptions = [get(d, "description", "") for d in data]

    has_url = any(haskey(d, "url") for d in data)
    if has_url
        urls = [get(d, "url", "") for d in data]
        return DataFrames.DataFrame(
            name = names,
            description = descriptions,
            url = urls,
        )
    end

    return DataFrames.DataFrame(name = names, description = descriptions)
end
