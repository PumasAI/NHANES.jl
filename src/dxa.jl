"""Valid years for DXA data."""
const DXA_YEARS = (1999, 2001, 2003, 2005)

"""
    dxa_tables(year::Int; suppl::Bool=false) -> DataFrame

List available DXA tables for a survey cycle.

# Arguments
- `year::Int`: Start year (1999, 2001, 2003, or 2005)
- `suppl::Bool=false`: If true, list supplemental tables (highly variable imputation data)

# Returns
- `DataFrame`: Available DXA tables with columns: name, description, url

# Examples
```julia
NHANES.dxa_tables(2005)
NHANES.dxa_tables(2005; suppl=true)
```
"""
function dxa_tables(year::Int; suppl::Bool = false)
    year in DXA_YEARS || throw(
        ArgumentError(
            "DXA data only available for years: $(join(DXA_YEARS, ", "))",
        ),
    )

    table_name = _dxa_table_name(year, suppl)
    desc =
        suppl ? "DXA - Highly Variable Imputation Data" :
        "Dual-Energy X-ray Absorptiometry - Whole Body"

    return DataFrames.DataFrame(
        name = [table_name],
        description = [desc],
        url = [_dxa_url(year, suppl)],
    )
end

"""
    dxa(year::Int; suppl::Bool=false, force::Bool=false) -> DataFrame

Download DXA data for a survey cycle.

Note: DXA data contains 5 sets of imputed values per participant.
Analyze all 5 sets separately - do NOT average them.

# Arguments
- `year::Int`: Start year (1999, 2001, 2003, or 2005)
- `suppl::Bool=false`: If true, download supplemental data (highly variable imputation)
- `force::Bool=false`: Force re-download even if cached

# Returns
- `DataFrame`: DXA measurements with 5 imputation sets

# Examples
```julia
dxa_data = NHANES.dxa(2005)
dxa_suppl = NHANES.dxa(2005; suppl=true)
```

# Throws
- `ArgumentError`: If the year has no DXA data
- `TableNotFoundError`: If CDC has no file for the table
- `DownloadError`: If the download fails for any other reason

# See Also
- [`dxa_tables`](@ref): List available DXA tables
"""
function dxa(year::Int; suppl::Bool = false, force::Bool = false)
    year in DXA_YEARS || throw(
        ArgumentError(
            "DXA data only available for years: $(join(DXA_YEARS, ", "))",
        ),
    )

    table_name = _dxa_table_name(year, suppl)
    cache_path = data_cache_path(table_name)

    if force || !is_cached(table_name)
        url = _dxa_url(year, suppl)
        try
            fetch_file(url, cache_path)
        catch e
            e isa DownloadError && e.status == 404 && throw(
                TableNotFoundError(
                    table_name,
                    "DXA table not found: $table_name ($url)",
                ),
            )
            rethrow()
        end
    end

    rst = ReadStatTables.readstat(cache_path)
    return DataFrames.DataFrame(rst)
end

"""Build DXA table name."""
function _dxa_table_name(year::Int, suppl::Bool)
    suppl_suffix = suppl ? "_S" : ""
    return "DXX" * cycle_suffix(year) * suppl_suffix
end

"""Build URL for DXA data file."""
function _dxa_url(year::Int, suppl::Bool)
    suppl_suffix = suppl ? "_s" : ""
    table_name = "dxx" * lowercase(cycle_suffix(year)) * suppl_suffix
    return "$BASE_URL/Nchs/Data/Nhanes/Public/$year/DataFiles/$table_name.xpt"
end
