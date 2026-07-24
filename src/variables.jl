"""
    variables(table::AbstractString; force::Bool=false) -> DataFrame

List variables in an NHANES data table.

# Arguments
- `table::AbstractString`: Table name with suffix (e.g., "DEMO_J")
- `force::Bool=false`: Force refresh from CDC (ignore cache)

# Returns
- `DataFrame`: Variables with columns:
  - `name`: Variable name
  - `label`: Variable description/label

# Examples
```julia
# List variables in 2017-2018 Demographics
NHANES.variables("DEMO_J")
```

# See Also
- [`codebook`](@ref): Get value codes for a variable
- [`download`](@ref): Download the table data
"""
function variables(table::AbstractString; force::Bool = false)
    if !force
        cached = load_metadata("variables", table)
        if cached !== nothing
            return _variables_to_dataframe(cached)
        end
    end

    url = codebook_url(table)
    html = fetch_html(url)

    vars_data = _parse_variables_from_codebook(html)

    save_metadata("variables", table, vars_data)

    return _variables_to_dataframe(vars_data)
end

"""
    _parse_variables_from_codebook(html::AbstractString) -> Vector{Dict}

Extract variable names and labels from a codebook page.
"""
function _parse_variables_from_codebook(html::AbstractString)
    doc = Lexbor.Document(html)
    vars_data = Dict{String, Any}[]

    # CDC codebook pages have variables in headers (h3) with format "VARNAME - Description"
    # Prefer h3.vartitle, fall back to all h3 if none found
    selector = "h3.vartitle"
    has_vartitle = false
    Lexbor.query(doc, "h3.vartitle") do _
        has_vartitle = true
    end
    if !has_vartitle
        selector = "h3"
    end

    Lexbor.query(doc, selector) do header
        text = strip(extract_text(header))
        if !isempty(text) && occursin(" - ", text)
            parts = split(text, " - "; limit = 2)
            name = strip(parts[1])
            label = length(parts) > 1 ? strip(parts[2]) : ""
            # Filter out non-variable headers
            if occursin(r"^[A-Z][A-Z0-9_]*$", name)
                push!(vars_data, Dict("name" => name, "label" => label))
            end
        end
    end

    return vars_data
end

"""
    _variables_to_dataframe(data::Vector) -> DataFrame

Convert parsed variables data to a DataFrame.
"""
function _variables_to_dataframe(data::Vector)
    if isempty(data)
        return DataFrames.DataFrame(name = String[], label = String[])
    end

    names = [d["name"] for d in data]
    labels = [get(d, "label", "") for d in data]

    return DataFrames.DataFrame(name = names, label = labels)
end
