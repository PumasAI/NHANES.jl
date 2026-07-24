"""Historical survey identifiers."""
const HISTORICAL_SURVEYS = (:nhanes1, :nhanes2, :nhanes3)

"""File extensions of the historical data files CDC publishes."""
const HISTORICAL_DATA_EXTENSIONS = (".xpt", ".dat", ".txt")

"""
    historical_tables(survey::Symbol; force::Bool=false) -> DataFrame

List available data files for a historical NHANES survey.

# Arguments
- `survey::Symbol`: One of :nhanes1, :nhanes2, :nhanes3
- `force::Bool=false`: Force refresh from CDC (ignore cache)

# Returns
- `DataFrame`: Available data files with columns: name, description, url

# Examples
```julia
NHANES.historical_tables(:nhanes3)
```

# Throws
- `ArgumentError`: If the survey is not one of the historical surveys
- `DownloadError`: If the listing page cannot be fetched

# Note
Historical survey data has different structure than continuous NHANES, so
[`download`](@ref) does not handle it. Fetch a listed file with
[`historical_download`](@ref) for the SAS transport files NHANES III publishes,
or [`historical_file`](@ref) for the fixed-width text files of NHANES I and II.

# See Also
- [`historical_download`](@ref): Read a listed transport file into a DataFrame
- [`historical_file`](@ref): Download any listed file and return its path
"""
function historical_tables(survey::Symbol; force::Bool = false)
    survey in HISTORICAL_SURVEYS || throw(
        ArgumentError(
            "Invalid historical survey: $survey. Must be one of: $(join(HISTORICAL_SURVEYS, ", "))",
        ),
    )

    if !force
        cached = load_metadata("historical", String(survey))
        cached === nothing || return _tables_to_dataframe(cached)
    end

    url = _historical_tables_url(survey)
    tables_data = _parse_historical_tables(fetch_html(url), url)
    save_metadata("historical", String(survey), tables_data)
    return _tables_to_dataframe(tables_data)
end

"""
    _historical_tables_url(survey::Symbol) -> String

Get URL for historical survey tables list.
NHANES I/II use default.aspx, NHANES III uses datafiles.aspx.
"""
function _historical_tables_url(survey::Symbol)
    page = survey == :nhanes3 ? "datafiles.aspx" : "default.aspx"
    return "$BASE_URL/nchs/nhanes/$survey/$page"
end

"""
    _parse_historical_tables(html::AbstractString, page_url::AbstractString) -> Vector{Dict}

Parse a historical survey listing page.
Names are derived from the data file names, which are more reliable than the
surrounding description cells. Links are resolved against `page_url`.
"""
function _parse_historical_tables(
        html::AbstractString,
        page_url::AbstractString,
    )
    doc = Lexbor.Document(html)
    tables_data = Dict{String, Any}[]
    seen_urls = Set{String}()

    Lexbor.query(doc, "a") do link
        href = get(Lexbor.attributes(link), "href", "")
        path, _ = _split_path(href)
        filename = basename(path)
        _is_historical_data_file(filename) || return

        url = resolve_url(page_url, href)
        url in seen_urls && return
        push!(seen_urls, url)

        name = uppercase(splitext(filename)[1])
        push!(
            tables_data,
            Dict("name" => name, "description" => "", "url" => url),
        )
    end

    return tables_data
end

"""
    _is_historical_data_file(filename::AbstractString) -> Bool

Report whether a linked file holds survey data. Readme files sit next to the
data files and share their extension, so they are excluded by name.
"""
function _is_historical_data_file(filename::AbstractString)
    lowered = lowercase(filename)
    any(ext -> endswith(lowered, ext), HISTORICAL_DATA_EXTENSIONS) ||
        return false
    return !occursin("readme", lowered)
end

"""
    historical_download(survey::Symbol, name::AbstractString; force::Bool=false) -> DataFrame

Download a historical NHANES SAS transport file and return it as a DataFrame.

`name` is resolved against the [`historical_tables`](@ref) listing for `survey`.
Only transport files (`.xpt`) can be read this way, which in practice means
NHANES III. NHANES I and II publish fixed-width text whose column layout lives
in a separate SAS input statement, so fetch those with [`historical_file`](@ref)
and parse them yourself.

Codes are left as published. Historical surveys have no codebook pages of the
kind [`translate`](@ref) reads.

# Arguments
- `survey::Symbol`: One of :nhanes1, :nhanes2, :nhanes3
- `name::AbstractString`: File name as reported by [`historical_tables`](@ref)
- `force::Bool=false`: If true, re-download even if cached

# Returns
- `DataFrame`: The requested data file

# Throws
- `ArgumentError`: If the survey is unknown, or the file is not a transport file
- `TableNotFoundError`: If the listing holds no file of that name
- `DownloadError`: If the download fails

# Examples
```julia
NHANES.historical_download(:nhanes3, "SSNH3MGM")
```

# See Also
- [`historical_tables`](@ref): List the files a survey publishes
- [`historical_file`](@ref): Download any listed file and return its path
"""
function historical_download(
        survey::Symbol,
        name::AbstractString;
        force::Bool = false,
    )
    entry = _historical_entry(survey, historical_tables(survey), name)
    _require_transport_file(entry)
    rst = ReadStatTables.readstat(_historical_fetch(survey, entry; force))
    return DataFrames.DataFrame(rst)
end

"""
    historical_file(survey::Symbol, name::AbstractString; force::Bool=false) -> String

Download a historical NHANES data file into the cache and return its path.

Handles every file [`historical_tables`](@ref) lists, whatever its format. Use
it for the fixed-width text of NHANES I and II: reading those needs the column
layout from the SAS input statement CDC publishes beside the data, which this
package does not carry.

# Arguments
- `survey::Symbol`: One of :nhanes1, :nhanes2, :nhanes3
- `name::AbstractString`: File name as reported by [`historical_tables`](@ref)
- `force::Bool=false`: If true, re-download even if cached

# Returns
- `String`: Path to the cached file, under the extension CDC publishes

# Throws
- `ArgumentError`: If the survey is not one of the historical surveys
- `TableNotFoundError`: If the listing holds no file of that name
- `DownloadError`: If the download fails

# Examples
```julia
path = NHANES.historical_file(:nhanes1, "DU4111")
```

# See Also
- [`historical_tables`](@ref): List the files a survey publishes
- [`historical_download`](@ref): Read a transport file into a DataFrame
"""
function historical_file(
        survey::Symbol,
        name::AbstractString;
        force::Bool = false,
    )
    entry = _historical_entry(survey, historical_tables(survey), name)
    return _historical_fetch(survey, entry; force)
end

"""
    _historical_entry(survey::Symbol, listing::DataFrames.DataFrame, name::AbstractString) -> NamedTuple

Find `name` in a survey listing, reporting its name, URL and file extension.
Lookup ignores case because listing names are always uppercase.

# Throws
- `TableNotFoundError`: If the listing holds no file of that name
"""
function _historical_entry(
        survey::Symbol,
        listing::DataFrames.DataFrame,
        name::AbstractString,
    )
    i = findfirst(==(uppercase(name)), listing.name)
    i === nothing && throw(
        TableNotFoundError(
            name,
            "No file named $name in the $survey listing. Use " *
                "NHANES.historical_tables($(repr(survey))) to list valid names.",
        ),
    )

    url = listing.url[i]
    path, _ = _split_path(url)
    return (
        name = listing.name[i],
        url = url,
        extension = lowercase(splitext(basename(path))[2]),
    )
end

"""Reject a listing entry that [`historical_download`](@ref) cannot read."""
function _require_transport_file(entry::NamedTuple)
    entry.extension == ".xpt" && return nothing
    throw(
        ArgumentError(
            "$(entry.name) is published as $(entry.extension), not a SAS " *
                "transport file. Reading it needs the column layout from " *
                "CDC's SAS input statement. Use NHANES.historical_file to " *
                "download the file and parse it yourself.",
        ),
    )
end

"""Path of the cached copy of `entry`, downloading it first when needed."""
function _historical_fetch(survey::Symbol, entry::NamedTuple; force::Bool)
    path = _historical_cache_path(survey, entry.name, entry.extension)
    (force || !isfile(path)) && fetch_file(entry.url, path)
    return path
end

"""
    _historical_cache_path(survey::Symbol, name::AbstractString, extension::AbstractString) -> String

Cache file path for a historical data file, keeping the extension CDC publishes
it under.

# Throws
- `ArgumentError`: If the name is not a plain identifier, or the extension is
  not one CDC publishes data under
"""
function _historical_cache_path(
        survey::Symbol,
        name::AbstractString,
        extension::AbstractString,
    )
    validate_name(name, "table name")
    extension in HISTORICAL_DATA_EXTENSIONS || throw(
        ArgumentError(
            "Invalid data file extension: $(repr(extension)). Must be one " *
                "of: $(join(HISTORICAL_DATA_EXTENSIONS, ", "))",
        ),
    )

    dir = joinpath(cache_dir(), "data", String(survey))
    mkpath(dir)
    return joinpath(dir, name * extension)
end
