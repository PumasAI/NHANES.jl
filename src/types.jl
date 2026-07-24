"""
    NHANESError <: Exception

Base exception type for all NHANES package errors.
"""
abstract type NHANESError <: Exception end

"""
    TableNotFoundError <: NHANESError

Thrown when a requested NHANES table does not exist.

# Fields
- `table::String`: The requested table name
- `message::String`: Descriptive error message
"""
struct TableNotFoundError <: NHANESError
    table::String
    message::String
end

function Base.showerror(io::IO, e::TableNotFoundError)
    return print(io, "TableNotFoundError: ", e.message)
end

"""
    DownloadError <: NHANESError

Thrown when downloading data from CDC fails.

# Fields
- `url::String`: The URL that failed
- `message::String`: Descriptive error message
- `status::Union{Int,Nothing}`: HTTP status code if available
"""
struct DownloadError <: NHANESError
    url::String
    message::String
    status::Union{Int, Nothing}
end

function Base.showerror(io::IO, e::DownloadError)
    print(io, "DownloadError: ", e.message)
    return if e.status !== nothing
        print(io, " (HTTP ", e.status, ")")
    end
end

"""
    MetadataError <: NHANESError

Thrown when parsing metadata (codebooks, variable lists) fails.

# Fields
- `source::String`: The metadata source (e.g., "codebook", "variable_list")
- `message::String`: Descriptive error message
"""
struct MetadataError <: NHANESError
    source::String
    message::String
end

function Base.showerror(io::IO, e::MetadataError)
    return print(io, "MetadataError: ", e.message, " (source: ", e.source, ")")
end

"""
Valid NHANES data components for continuous NHANES (1999-present).
"""
const COMPONENTS =
    (:Demographics, :Dietary, :Examination, :Laboratory, :Questionnaire)

"""
Mapping from R-style short component names to full names.
"""
const COMPONENT_ALIASES = Dict{Symbol, Symbol}(
    :DEMO => :Demographics,
    :DIET => :Dietary,
    :EXAM => :Examination,
    :LAB => :Laboratory,
    :Q => :Questionnaire,
)

"""
Mapping from lowercased component spellings, both full names and R-style
aliases, to full names. Backs case-insensitive lookup.
"""
const COMPONENT_LOOKUP = merge(
    Dict{String, Symbol}(lowercase(String(c)) => c for c in COMPONENTS),
    Dict{String, Symbol}(
        lowercase(String(alias)) => full for (alias, full) in COMPONENT_ALIASES
    ),
)

"""
    normalize_component(comp::Symbol) -> Symbol

Convert a component name to its full form.
Accepts full names and R-style short names (:DEMO, :DIET, :EXAM, :LAB, :Q),
both case-insensitive.
Returns: :Demographics, :Dietary, :Examination, :Laboratory, :Questionnaire
"""
function normalize_component(comp::Symbol)
    full = get(COMPONENT_LOOKUP, lowercase(String(comp)), nothing)
    full === nothing && throw(
        ArgumentError(
            "Invalid component: $comp. Must be one of: $(join(COMPONENTS, ", ")) " *
                "or R-style: DEMO, DIET, EXAM, LAB, Q",
        ),
    )
    return full
end

"""Names that are safe to embed in a cache path or a CDC URL."""
const SAFE_NAME = r"^[A-Za-z0-9_]+$"

"""
    validate_name(name::AbstractString, kind::AbstractString) -> String

Check that a name cannot escape the directory or URL path it is joined into.
Returns the name unchanged.

# Throws
- `ArgumentError`: If the name contains anything but letters, digits and
  underscores
"""
function validate_name(name::AbstractString, kind::AbstractString)
    occursin(SAFE_NAME, name) || throw(
        ArgumentError(
            "Invalid $kind: $(repr(name)). Only letters, digits and " *
                "underscores are allowed.",
        ),
    )
    return name
end

"""
Mapping of survey cycle start years to table suffixes.

Continuous NHANES uses letter suffixes starting from 1999-2000:
- 1999-2000: no suffix (or sometimes _A in older tables)
- 2001-2002: _B
- 2003-2004: _C
- etc.

The 2019-2020 cycle was cut short by COVID-19 and never published on its own.
Its data was released as part of the 2017-March 2020 pre-pandemic files, and
CDC skipped the letter _K, so 2021-2023 uses _L.
"""
const SURVEY_CYCLES = Dict{Int, String}(
    1999 => "",
    2001 => "_B",
    2003 => "_C",
    2005 => "_D",
    2007 => "_E",
    2009 => "_F",
    2011 => "_G",
    2013 => "_H",
    2015 => "_I",
    2017 => "_J",
    2021 => "_L",  # 2021-2023
)

"""Mapping of table suffixes back to survey cycle start years."""
const SUFFIX_TO_YEAR =
    Dict{String, Int}(suffix => year for (year, suffix) in SURVEY_CYCLES)

"""
    survey_years() -> Vector{Int}

List the start years of every published survey cycle, in ascending order.
"""
survey_years() = sort!(collect(keys(SURVEY_CYCLES)))

"""
Pre-pandemic cycle identifier (2017-March 2020).
Tables use P_ prefix instead of suffix.
"""
const PREPANDEMIC_CYCLE = :P
