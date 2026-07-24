"""Code cell CDC uses for the missing row of a numeric value table."""
const MISSING_CODE = "."

"""Code cells CDC uses for the missing row, numeric and character."""
const MISSING_CODES = (MISSING_CODE, "< blank >")

"""Description CDC uses for the row covering a variable's measured range."""
const RANGE_DESCRIPTION = "Range of Values"

"""
    _is_missing_row(code::AbstractString) -> Bool

Report whether a value table row counts missing observations rather than a
code.
"""
_is_missing_row(code::AbstractString) = code in MISSING_CODES

"""
    _is_blank(val) -> Bool

Report whether a data value is absent. A character column records a blank
string where a numeric column records missing.
"""
_is_blank(val) = ismissing(val) || (val isa AbstractString && isempty(val))

"""
    codebook(table::AbstractString, variable::Symbol; force::Bool=false) -> DataFrame

Get the codebook (value codes and labels) for a variable.

Codes and labels come from the CDC codebook page, one row per row CDC
publishes. Counts are computed from the data, so a continuous variable reports
how many observations fall in its published range rather than one row per
distinct measurement.

# Arguments
- `table::AbstractString`: Table name with suffix (e.g., "DEMO_J")
- `variable::Symbol`: Variable name (e.g., :RIAGENDR)
- `force::Bool=false`: Force refresh from CDC (ignore cache)

# Returns
- `DataFrame`: Value codes with columns:
  - `code::String`: Code exactly as CDC publishes it, `"."` for missing
  - `label::String`: Human-readable label
  - `count::Int`: Number of observations in the data

# Examples
```julia
# Get gender codes from 2017-2018 Demographics
NHANES.codebook("DEMO_J", :RIAGENDR)
# code | label   | count
# "1"  | Male    | 4557
# "2"  | Female  | 4697
# "."  | Missing | 0

# A continuous variable reports its range, not every observed value
NHANES.codebook("BMX_J", :BMXWT)
# code           | label           | count
# "3.2 to 242.6" | Range of Values | 8580
# "."            | Missing         | 124
```

# See Also
- [`variables`](@ref): List all variables in a table
- [`translate!`](@ref): Apply codebook labels to a DataFrame
"""
function codebook(table::AbstractString, variable::Symbol; force::Bool = false)
    var_str = String(variable)

    value_tables = _get_table_labels(table; force = force)

    if !haskey(value_tables, var_str)
        throw(
            MetadataError(
                "codebook",
                "Variable $variable not found in table $table codebook",
            ),
        )
    end

    # Counts are keyed on the published codes, so the data must stay untranslated.
    df = download(table; translate = false)

    if !hasproperty(df, variable)
        throw(
            MetadataError(
                "codebook",
                "Variable $variable not found in table $table data",
            ),
        )
    end

    return _build_codebook_from_data(df, variable, value_tables[var_str])
end

"""
    _get_table_labels(table::AbstractString; force::Bool=false) -> Dict

Get the parsed value table for every variable in a data table, using cache if
available.
Returns Dict mapping variable name -> value table, as built by
[`_parse_all_value_labels`](@ref).
"""
function _get_table_labels(table::AbstractString; force::Bool = false)
    cache_key = "$(table)_valuetables"

    if !force
        cached = load_metadata("codebook", cache_key)
        if cached !== nothing
            return cached
        end
    end

    url = codebook_url(table)
    html = fetch_html(url)
    value_tables = _parse_all_value_labels(html)

    save_metadata("codebook", cache_key, value_tables)
    return value_tables
end

"""
    _is_range_row(code::AbstractString, label::AbstractString) -> Bool

Report whether a value table row describes a range of measurements rather than
a single code. CDC marks these rows with the description "Range of Values" and
a code cell such as "3.2 to 242.6". A character variable's recorded values are
also ranges: their code cell repeats the variable description.
"""
function _is_range_row(code::AbstractString, label::AbstractString)
    label == RANGE_DESCRIPTION && return true
    _is_missing_row(code) && return false
    return tryparse(Float64, code) === nothing
end

"""
    _parse_all_value_labels(html::AbstractString) -> Dict{String,Any}

Parse the value table of every variable on a codebook page.

Returns Dict mapping variable name -> Dict with:
- `"continuous"`: true when the variable has a range row, so its values are
  measurements rather than codes
- `"labels"`: Dict(code_string -> label) for code rows only
- `"rows"`: every published row, in order, as Dict("code" =>, "label" =>)
"""
function _parse_all_value_labels(html::AbstractString)
    doc = Lexbor.Document(html)
    value_tables = Dict{String, Any}()

    section_selector = "div.pagebreak"
    has_pagebreak = false
    Lexbor.query(doc, "div.pagebreak") do _
        has_pagebreak = true
    end
    if !has_pagebreak
        section_selector = "div"
    end

    header_selector = "h3.vartitle"
    has_vartitle = false
    Lexbor.query(doc, "h3.vartitle") do _
        has_vartitle = true
    end
    if !has_vartitle
        header_selector = "h3"
    end

    Lexbor.query(doc, section_selector) do section
        var_name = nothing

        Lexbor.query(section, header_selector) do header
            text = strip(extract_text(header))
            if occursin(" - ", text)
                var_name = strip(split(text, " - "; limit = 2)[1])
            end
        end

        var_name === nothing && return

        rows = Any[]
        labels = Dict{String, Any}()
        continuous = false

        Lexbor.query(section, "table") do tbl
            Lexbor.query(tbl, "tbody tr") do row
                cells = String[]
                Lexbor.query(row, "td") do td
                    push!(cells, strip(extract_text(td)))
                end

                # Format: Code | Label | Count (we only need code and label)
                if length(cells) >= 2 && !isempty(cells[1])
                    code, label = cells[1], cells[2]
                    push!(
                        rows,
                        Dict{String, Any}("code" => code, "label" => label),
                    )
                    if _is_range_row(code, label)
                        continuous = true
                    elseif !_is_missing_row(code)
                        labels[code] = label
                    end
                end
            end
        end

        if !isempty(rows)
            value_tables[var_name] = Dict{String, Any}(
                "continuous" => continuous,
                "labels" => labels,
                "rows" => rows,
            )
        end
    end

    return value_tables
end

"""
    _code_sort_key(code::AbstractString)

Sort key placing numeric codes in numeric order ahead of non-numeric ones.
"""
_code_sort_key(code::AbstractString) = (something(tryparse(Float64, code), Inf), code)

"""
    _build_codebook_from_data(df::DataFrames.DataFrame, variable::Symbol, entry) -> DataFrame

Build codebook DataFrame with counts computed from actual data.

Emits one row per row CDC publishes, in order. Values matching no published
code are appended so the counts account for every observation.
"""
function _build_codebook_from_data(
        df::DataFrames.DataFrame,
        variable::Symbol,
        entry,
    )
    counts = Dict{String, Int}()
    missing_count = 0
    for val in df[!, variable]
        if _is_blank(val)
            missing_count += 1
        else
            code = _format_code(val)
            counts[code] = get(counts, code, 0) + 1
        end
    end

    rows = entry["rows"]
    published = Set{String}(
        row["code"]::String for row in rows if !_is_missing_row(row["code"])
    )

    codes = String[]
    labels = String[]
    cnts = Int[]
    has_missing_row = false
    has_range_row = false

    for row in rows
        code = row["code"]::String
        label = row["label"]::String
        push!(codes, code)
        push!(labels, label)

        if _is_missing_row(code)
            has_missing_row = true
            push!(cnts, missing_count)
        elseif _is_range_row(code, label)
            has_range_row = true
            # Everything the special codes do not claim falls in the range
            push!(
                cnts,
                sum((n for (c, n) in counts if !(c in published)); init = 0),
            )
        else
            push!(cnts, get(counts, code, 0))
        end
    end

    if !has_range_row
        extra =
            sort!([c for c in keys(counts) if !(c in published)]; by = _code_sort_key)
        for code in extra
            push!(codes, code)
            push!(labels, "")
            push!(cnts, counts[code])
        end
    end

    if !has_missing_row && missing_count > 0
        push!(codes, MISSING_CODE)
        push!(labels, "Missing")
        push!(cnts, missing_count)
    end

    return DataFrames.DataFrame(code = codes, label = labels, count = cnts)
end
