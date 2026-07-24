import Documenter
import NHANES

Documenter.DocMeta.setdocmeta!(
    NHANES,
    :DocTestSetup,
    :(import NHANES);
    recursive = true,
)

Documenter.makedocs(;
    modules = [NHANES],
    sitename = "NHANES.jl",
    authors = "Pumas-AI, Inc. and contributors",
    repo = Documenter.Remotes.GitHub("PumasAI", "NHANES.jl"),
    format = Documenter.HTML(;
        canonical = "https://PumasAI.github.io/NHANES.jl",
        edit_link = "main",
        prettyurls = get(ENV, "CI", "false") == "true",
    ),
    pages = [
        "Home" => "index.md",
        "Guide" => "guide.md",
        "Survey cycles and table names" => "cycles.md",
        "Coming from nhanesA" => "nhanesa.md",
        "API reference" => "api.md",
        "Internals" => "internals.md",
    ],
    doctest = true,
    checkdocs = :all,
)

Documenter.deploydocs(;
    repo = "github.com/PumasAI/NHANES.jl",
    devbranch = "main",
    push_preview = true,
)
