# XPT data files are cached indefinitely (NHANES data is immutable once published).
# Metadata (codebooks, variable lists) are cached with a TTL.

import Dates

"""Number of days before metadata cache is considered stale."""
const METADATA_TTL_DAYS = 30

"""
Cache root to use instead of the Scratch.jl space, or `nothing` for the
default. Tests redirect the cache here so they never touch a real download
cache; see [`with_cache_dir`](@ref).
"""
const CACHE_ROOT_OVERRIDE = Ref{Union{Nothing, String}}(nothing)

"""
    cache_dir() -> String

Get the root cache directory for NHANES data.
Creates the directory if it doesn't exist.
"""
function cache_dir()
    root = CACHE_ROOT_OVERRIDE[]
    root === nothing && return Scratch.@get_scratch!("nhanes")
    mkpath(root)
    return root
end

"""
    with_cache_dir(f, dir::AbstractString)

Run `f` with the cache root redirected to `dir`, restoring the previous root
afterwards.
"""
function with_cache_dir(f, dir::AbstractString)
    previous = CACHE_ROOT_OVERRIDE[]
    CACHE_ROOT_OVERRIDE[] = dir
    try
        return f()
    finally
        CACHE_ROOT_OVERRIDE[] = previous
    end
end

"""
    data_cache_path(table::AbstractString) -> String

Get the cache file path for a data table.

# Throws
- `ArgumentError`: If the table name is not a plain identifier
"""
function data_cache_path(table::AbstractString)
    validate_name(table, "table name")
    dir = joinpath(cache_dir(), "data")
    mkpath(dir)
    return joinpath(dir, "$table.xpt")
end

"""
    metadata_cache_path(category::AbstractString, key::AbstractString) -> String

Get the cache file path for metadata.

# Throws
- `ArgumentError`: If the category or key is not a plain identifier
"""
function metadata_cache_path(category::AbstractString, key::AbstractString)
    validate_name(category, "metadata category")
    validate_name(key, "metadata key")
    dir = joinpath(cache_dir(), "metadata", category)
    mkpath(dir)
    return joinpath(dir, "$key.json")
end

"""
    is_cached(table::AbstractString) -> Bool

Check if a data table is cached.
"""
function is_cached(table::AbstractString)
    return isfile(data_cache_path(table))
end

"""
    is_metadata_fresh(path::AbstractString) -> Bool

Check if a metadata cache file exists and is within the TTL.
"""
function is_metadata_fresh(path::AbstractString)
    !isfile(path) && return false

    mtime = Dates.unix2datetime(stat(path).mtime)
    age_days = Dates.value(Dates.now() - mtime) / (1000 * 60 * 60 * 24)

    return age_days < METADATA_TTL_DAYS
end

"""
    save_metadata(category::AbstractString, key::AbstractString, data) -> String

Save metadata to the cache as JSON.
"""
function save_metadata(category::AbstractString, key::AbstractString, data)
    path = metadata_cache_path(category, key)
    temp = tempname(dirname(path); cleanup = false)
    try
        open(temp, "w") do io
            JSON.print(io, data)
        end
        mv(temp, path; force = true)
    catch
        rm(temp; force = true)
        rethrow()
    end
    return path
end

"""
    load_metadata(category::AbstractString, key::AbstractString)

Load metadata from the cache.

# Returns
- Parsed JSON data, or `nothing` if not cached or stale
"""
function load_metadata(category::AbstractString, key::AbstractString)
    path = metadata_cache_path(category, key)

    if !is_metadata_fresh(path)
        return nothing
    end

    return JSON.parsefile(path)
end

"""
    clear_cache()

Remove all cached data and metadata.
"""
function clear_cache()
    dir = cache_dir()
    if isdir(dir)
        rm(dir; recursive = true)
    end
    mkpath(dir)
    return nothing
end
