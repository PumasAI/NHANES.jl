import AbstractTrees

"""
    extract_text(node) -> String

Concatenate the text content of an HTML node and its descendants.

Text nodes are joined without a separator, so inline markup inside a cell does
not introduce whitespace that the rendered page does not have.
"""
function extract_text(node)
    parts = String[]

    for child in AbstractTrees.PreOrderDFS(node)
        if Lexbor.is_text(child)
            push!(parts, Lexbor.text(child))
        end
    end

    return join(parts)
end

"""
    table_rows(html::AbstractString) -> Vector{Vector{String}}

Extract the text of the `td` cells of every table row on a page, one entry per
row. Header rows, which hold `th` cells, come back empty.

# Returns
- `Vector{Vector{String}}`: Cell text per row, in document order
"""
function table_rows(html::AbstractString)
    doc = Lexbor.Document(html)
    rows = Vector{String}[]

    Lexbor.query(doc, "tr") do row
        cells = String[]
        Lexbor.query(row, "td") do td
            push!(cells, strip(extract_text(td)))
        end
        push!(rows, cells)
    end

    return rows
end

"""
    parse_variablelist_html(html::AbstractString) -> Vector{Dict}

Parse a variable list HTML page.

# Returns
- `Vector{Dict}`: One entry per variable, with `name`, `description`, `table`
  and `table_description` keys
"""
function parse_variablelist_html(html::AbstractString)
    variables = Dict{String, Any}[]

    for cells in table_rows(html)
        length(cells) >= 2 && !isempty(cells[1]) || continue

        var = Dict{String, Any}(
            "name" => cells[1],
            "description" => cells[2],
        )
        if length(cells) >= 3
            var["table"] = cells[3]
        end
        if length(cells) >= 4
            var["table_description"] = cells[4]
        end
        push!(variables, var)
    end

    return variables
end
