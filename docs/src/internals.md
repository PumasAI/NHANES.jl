```@meta
CurrentModule = NHANES
DocTestSetup = :(import NHANES)
```

# Internals

Everything the API reference does not list, including names without a leading
underscore. None of it carries a compatibility guarantee.

The two filters partition the module and `checkdocs = :all` fails the build on
any docstring that falls through both, so a name added to one list and not
removed from the other cannot slip past CI.

```@autodocs
Modules = [NHANES]
Order = [:type, :function, :constant]
Filter = t -> !((t isa Union{Function, Type}) && nameof(t) in (
    :NHANESError, :TableNotFoundError, :DownloadError, :MetadataError,
    :download, :tables, :variables, :codebook,
    :translate, :translate!,
    :search, :search_var_name, :search_table_names,
    :dxa, :dxa_tables,
    :historical_tables, :historical_download, :historical_file,
    :clear_cache,
))
```
