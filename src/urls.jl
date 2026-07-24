const BASE_URL = "https://wwwn.cdc.gov"

"""
    cycle_suffix(year::Int) -> String

Get the table suffix for a given survey cycle start year.

# Throws
- `ArgumentError`: If the year is not a published cycle. 2019 gets a dedicated
  message pointing at the pre-pandemic cycle `:P`.

# Examples
```julia
cycle_suffix(1999)  # ""
cycle_suffix(2017)  # "_J"
```
"""
function cycle_suffix(year::Int)
    year == 2019 && throw(
        ArgumentError(
            "NHANES 2019-2020 was never released publicly: data collection " *
                "was cut short by COVID-19 and the results were folded into the " *
                "2017-March 2020 pre-pandemic files. Use the pre-pandemic cycle " *
                ":P instead.",
        ),
    )
    haskey(SURVEY_CYCLES, year) || throw(
        ArgumentError(
            "Invalid survey cycle year: $year. Must be an odd year >= 1999 (e.g., 1999, 2001, 2003, ...)",
        ),
    )
    return SURVEY_CYCLES[year]
end

"""
    suffix_to_year(suffix::AbstractString) -> Int

Convert a table suffix to the survey cycle start year. The leading underscore is
optional.

# Examples
```julia
suffix_to_year("_J")  # 2017
suffix_to_year("B")   # 2001
suffix_to_year("")    # 1999
```
"""
function suffix_to_year(suffix::AbstractString)
    s = suffix
    if !isempty(s) && !startswith(s, "_")
        s = "_" * s
    end

    year = get(SUFFIX_TO_YEAR, s, nothing)
    year === nothing && throw(ArgumentError("Unknown table suffix: $suffix"))
    return year
end

"""
    parse_table_name(table::AbstractString) -> Tuple{String, String}

Parse a table name into its base name and cycle marker.

# Returns
- `Tuple{String, String}`: (base_name, cycle_marker)
  - For suffix tables: ("DEMO", "_J")
  - For P_ prefix tables: ("BMX", "P_")
  - For 1999-2000 tables: ("DEMO", "")

# Examples
```julia
parse_table_name("DEMO_J")    # ("DEMO", "_J")
parse_table_name("ALB_CR_J")  # ("ALB_CR", "_J")
parse_table_name("P_BMX")     # ("BMX", "P_")
parse_table_name("DEMO")      # ("DEMO", "")
```
"""
function parse_table_name(table::AbstractString)
    if startswith(table, "P_")
        return (table[3:end], "P_")
    end

    parts = split(table, "_")

    if length(parts) >= 2
        last_part = parts[end]
        if length(last_part) == 1 && occursin(r"^[A-Z]$", last_part)
            suffix = "_" * last_part
            if haskey(SUFFIX_TO_YEAR, suffix)
                base = join(parts[1:(end - 1)], "_")
                return (base, suffix)
            end
        end
    end

    return (table, "")
end

"""
    table_url(table::AbstractString) -> String

Build the download URL for an NHANES data table.

# Examples
```julia
table_url("DEMO_J")
# "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DEMO_J.xpt"

table_url("P_BMX")
# "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_BMX.xpt"
```
"""
function table_url(table::AbstractString)
    validate_name(table, "table name")
    _, marker = parse_table_name(table)

    # P_ prefix tables are stored in 2017 folder
    if marker == "P_"
        return "$BASE_URL/Nchs/Data/Nhanes/Public/2017/DataFiles/$table.xpt"
    end

    year = suffix_to_year(marker)
    return "$BASE_URL/Nchs/Data/Nhanes/Public/$year/DataFiles/$table.xpt"
end

"""
    variablelist_url(component::Symbol, year::Union{Int,Symbol}) -> String

Build the URL for the variable list page.
"""
function variablelist_url(component::Symbol, year::Union{Int, Symbol})
    component in COMPONENTS || throw(
        ArgumentError(
            "Invalid component: $component. Must be one of: $(join(COMPONENTS, ", "))",
        ),
    )

    # Pre-pandemic cycle uses different URL parameter
    if year === PREPANDEMIC_CYCLE
        return "$BASE_URL/nchs/nhanes/search/variablelist.aspx?Component=$component&Cycle=2017-2020"
    end

    return "$BASE_URL/nchs/nhanes/search/variablelist.aspx?Component=$component&CycleBeginYear=$year"
end

"""
    codebook_url(table::AbstractString) -> String

Build the URL for a table's codebook/documentation page.
"""
function codebook_url(table::AbstractString)
    validate_name(table, "table name")
    _, marker = parse_table_name(table)

    # P_ prefix tables are stored in 2017 folder
    if marker == "P_"
        return "$BASE_URL/Nchs/Data/Nhanes/Public/2017/DataFiles/$table.htm"
    end

    year = suffix_to_year(marker)
    return "$BASE_URL/Nchs/Data/Nhanes/Public/$year/DataFiles/$table.htm"
end

"""
    resolve_url(base::AbstractString, href::AbstractString) -> String

Resolve a link against the absolute URL of the page it appeared on.

Absolute links are returned unchanged and protocol-relative links take the
scheme of `base`. Everything else is joined onto `base`, with `.` and `..`
segments collapsed and `..` stopping at the root.

# Throws
- `ArgumentError`: If `base` is not an absolute URL

# Examples
```julia
resolve_url(
    "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/datafiles.aspx",
    "../../data/nhanes3/1a/adult.dat",
)
# "https://wwwn.cdc.gov/nchs/data/nhanes3/1a/adult.dat"
```
"""
function resolve_url(base::AbstractString, href::AbstractString)
    occursin(r"^[A-Za-z][A-Za-z0-9+.-]*:", href) && return String(href)

    m = match(r"^([A-Za-z][A-Za-z0-9+.-]*:)//([^/?#]*)(.*)$", base)
    m === nothing &&
        throw(ArgumentError("Base URL is not absolute: $(repr(base))"))
    scheme, authority, base_rest = m[1], m[2], m[3]

    startswith(href, "//") && return string(scheme, href)

    path, suffix = _split_path(href)
    base_path, _ = _split_path(base_rest)

    # An empty reference path points at the base document itself.
    isempty(path) &&
        return string(scheme, "//", authority, base_path, suffix)

    absolute =
        startswith(path, "/") ? path : string(_directory(base_path), path)

    return string(scheme, "//", authority, _normalize_path(absolute), suffix)
end

"""Split a URL path from the query string or fragment that follows it."""
function _split_path(url::AbstractString)
    i = findfirst(c -> c == '?' || c == '#', url)
    i === nothing && return String(url), ""
    return String(url[1:prevind(url, i)]), String(url[i:end])
end

"""Directory part of a URL path, including the trailing slash."""
function _directory(path::AbstractString)
    i = findlast(==('/'), path)
    i === nothing && return "/"
    return String(path[1:i])
end

"""Collapse `.` and `..` segments in an absolute URL path."""
function _normalize_path(path::AbstractString)
    segments = String[]
    for segment in split(path, '/')
        if isempty(segment) || segment == "."
            continue
        elseif segment == ".."
            isempty(segments) || pop!(segments)
        else
            push!(segments, segment)
        end
    end

    trailing = endswith(path, "/") || endswith(path, "/.") || endswith(path, "/..")
    return string("/", join(segments, "/"), trailing && !isempty(segments) ? "/" : "")
end
