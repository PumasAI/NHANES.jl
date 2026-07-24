"""
    download(table::AbstractString; translate::Bool=true, force::Bool=false) -> DataFrame

Download an NHANES data table and return it as a DataFrame.

Translation applies to categorical variables only. A variable whose codebook
publishes a range of values is a measurement, so its column keeps its numeric
element type and its coded missing values (7777 "Refused", 9999 "Don't know"
and friends) stay numeric. Call [`codebook`](@ref) to find out which numbers a
continuous variable reserves for those meanings, and filter them out before
analysis.

# Arguments
- `table::AbstractString`: Table name with suffix (e.g., "DEMO_J" for 2017-2018 Demographics)
- `translate::Bool=true`: Translate coded values to human-readable labels
- `force::Bool=false`: If true, re-download even if cached

# Returns
- `DataFrame`: The requested data table

# Throws
- `TableNotFoundError`: If CDC has no such table
- `DownloadError`: If the download fails for any other reason

# Examples
```julia
# Download 2017-2018 Demographics
demo = NHANES.download("DEMO_J")

# Download without value translation
demo = NHANES.download("DEMO_J"; translate=false)
```

# See Also
- [`tables`](@ref): List available tables for a component and year
- [`variables`](@ref): List variables in a table
- [`codebook`](@ref): Codes and labels for a single variable
"""
function download(
        table::AbstractString;
        translate::Bool = true,
        force::Bool = false,
    )
    cache_path = data_cache_path(table)

    if force || !is_cached(table)
        url = table_url(table)
        try
            fetch_file(url, cache_path)
        catch err
            err isa DownloadError && err.status == 404 || rethrow()
            throw(
                TableNotFoundError(
                    table,
                    "No NHANES table named $table at $url. Use " *
                        "NHANES.tables(component, year) to list valid table names.",
                ),
            )
        end
    end

    rst = ReadStatTables.readstat(cache_path)
    df = DataFrames.DataFrame(rst)

    if translate
        _apply_labels!(df, table)
    end

    return df
end

"""
    _apply_labels!(df::DataFrames.DataFrame, table::AbstractString)

Apply value labels to the categorical columns of a DataFrame.
Continuous columns keep their numeric values.
Uses cached labels, no redundant downloads.
"""
function _apply_labels!(df::DataFrames.DataFrame, table::AbstractString)
    value_tables = _get_table_labels(table)

    for col_name in names(df)
        haskey(value_tables, col_name) || continue
        entry = value_tables[col_name]
        entry["continuous"]::Bool && continue

        translated, unmatched = _translate_column(df[!, col_name], entry["labels"])
        _warn_unmatched(table, col_name, unmatched)
        df[!, col_name] = translated
    end
    return
end

"""
    _translate_column(col, labels_map) -> (Vector{Union{String,Missing}}, Set{String})

Replace codes with labels, keeping unlabelled values as strings.
Returns the translated column and the codes that had no label.
"""
function _translate_column(col, labels_map)
    translated = Vector{Union{String, Missing}}(undef, length(col))
    unmatched = Set{String}()

    for (i, val) in enumerate(col)
        if ismissing(val)
            translated[i] = missing
        else
            code = _format_code(val)
            label = get(labels_map, code, nothing)
            if label === nothing
                push!(unmatched, code)
                translated[i] = string(val)
            else
                translated[i] = label
            end
        end
    end

    return translated, unmatched
end

"""
    _warn_unmatched(table::AbstractString, column::AbstractString, codes)

Report codes present in the data that the codebook does not describe.
"""
function _warn_unmatched(table::AbstractString, column::AbstractString, codes)
    isempty(codes) && return
    sorted = sort!(collect(codes); by = _code_sort_key)
    @warn "Values with no codebook label kept as strings." table column codes = sorted
    return
end

"""Format numeric code for label lookup."""
function _format_code(val::Real)
    return val == floor(val) ? string(Int(val)) : string(val)
end
_format_code(val::AbstractString) = String(val)
