```@meta
CurrentModule = NHANES
DocTestSetup = :(import NHANES)
```

# API reference

Nothing is exported, so every name below is reached as `NHANES.name`. This page
is the supported surface. Anything absent from it is an implementation detail,
documented under [Internals](@ref).

```@index
Pages = ["api.md"]
```

```@autodocs
Modules = [NHANES]
Order = [:type, :function, :constant]
Filter = t -> (t isa Union{Function, Type}) && nameof(t) in (
    :NHANESError, :TableNotFoundError, :DownloadError, :MetadataError,
    :download, :tables, :variables, :codebook,
    :translate, :translate!,
    :search, :search_var_name, :search_table_names,
    :dxa, :dxa_tables,
    :historical_tables, :historical_download, :historical_file,
    :clear_cache,
)
```
