"""
    translate!(df::DataFrame, table::AbstractString, column::Symbol)

Replace numeric codes with text labels in-place.

Only the codebook labels are fetched, so translating several columns reads the
data table once.

# Arguments
- `df::DataFrame`: DataFrame to modify
- `table::AbstractString`: Table name (for looking up codebook)
- `column::Symbol`: Column to translate

# Throws
- `MetadataError`: If the codebook does not describe the column
- `ArgumentError`: If the column holds measurements rather than codes

# Examples
```julia
demo = NHANES.download("DEMO_J"; translate=false)
NHANES.translate!(demo, "DEMO_J", :RIAGENDR)
# Column now contains "Male"/"Female" instead of 1/2
```

# See Also
- [`translate`](@ref): Non-mutating version
- [`codebook`](@ref): View available codes
"""
function translate!(
        df::DataFrames.DataFrame,
        table::AbstractString,
        column::Symbol,
    )
    var_str = String(column)
    value_tables = _get_table_labels(table)

    if !haskey(value_tables, var_str)
        throw(
            MetadataError(
                "codebook",
                "Variable $column not found in table $table codebook",
            ),
        )
    end

    entry = value_tables[var_str]
    if entry["continuous"]::Bool
        throw(
            ArgumentError(
                "$column holds measurements in $table, not codes. Labelling " *
                    "them would discard the values. Use " *
                    "codebook($(repr(table)), :$column) to see the codes it " *
                    "reserves for missing data.",
            ),
        )
    end

    translated, unmatched = _translate_column(df[!, column], entry["labels"])
    _warn_unmatched(table, var_str, unmatched)

    df[!, column] = translated
    return df
end

"""
    translate!(df::DataFrame, table::AbstractString, columns::Vector{Symbol})

Translate multiple columns in-place.
"""
function translate!(
        df::DataFrames.DataFrame,
        table::AbstractString,
        columns::Vector{Symbol},
    )
    for col in columns
        translate!(df, table, col)
    end
    return df
end

"""
    translate(df::DataFrame, table::AbstractString, column::Symbol) -> DataFrame
    translate(df::DataFrame, table::AbstractString, columns::Vector{Symbol}) -> DataFrame

Return a new DataFrame with codes replaced by labels.

Non-mutating version of [`translate!`](@ref).

# Arguments
- `df::DataFrame`: Source DataFrame
- `table::AbstractString`: Table name (for looking up codebook)
- `column::Symbol` or `columns::Vector{Symbol}`: Column(s) to translate

# Returns
- `DataFrame`: New DataFrame with translated column(s)

# Examples
```julia
demo = NHANES.download("DEMO_J"; translate=false)
demo_labeled = NHANES.translate(demo, "DEMO_J", :RIAGENDR)
demo_labeled = NHANES.translate(demo, "DEMO_J", [:RIAGENDR, :RIDRETH1])
```
"""
function translate(
        df::DataFrames.DataFrame,
        table::AbstractString,
        column::Symbol,
    )
    df_copy = copy(df)
    translate!(df_copy, table, column)
    return df_copy
end

function translate(
        df::DataFrames.DataFrame,
        table::AbstractString,
        columns::Vector{Symbol},
    )
    df_copy = copy(df)
    translate!(df_copy, table, columns)
    return df_copy
end
