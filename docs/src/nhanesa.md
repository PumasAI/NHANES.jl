# Coming from nhanesA

R's [nhanesA](https://cran.r-project.org/package=nhanesA) covers the same data.
The call names map across directly.

| nhanesA (R) | NHANES.jl |
|---|---|
| `nhanes("DEMO_J")` | `NHANES.download("DEMO_J")` |
| `nhanes("DEMO_J", translate=FALSE)` | `NHANES.download("DEMO_J"; translate=false)` |
| `nhanesTables("EXAM", 2005)` | `NHANES.tables(:EXAM, 2005)` |
| `nhanesTableVars("EXAM", "BMX_D")` | `NHANES.variables("BMX_D")` |
| `nhanesCodebook("DEMO_D", "RIAGENDR")` | `NHANES.codebook("DEMO_D", :RIAGENDR)` |
| `nhanesTranslate("BPX_D", "BPXSY1", data=df)` | `NHANES.translate!(df, "BPX_D", :BPXSY1)` |
| `nhanesSearch("glucose")` | `NHANES.search("glucose")` |
| `nhanesSearchVarName("BMXLEG")` | `NHANES.search_var_name("BMXLEG")` |
| `nhanesSearchTableNames("BMX")` | `NHANES.search_table_names("BMX")` |
| `nhanesDXA(2005)` | `NHANES.dxa(2005)` |
| `nhanesDXA(2005, suppl=TRUE)` | `NHANES.dxa(2005; suppl=true)` |

## Where the two differ

Both translate coded values by default, but they disagree on continuous
variables. `nhanesA` converts a column to character as soon as the codebook
reserves any code, so age, income ratio and the survey weights come back as
strings. NHANES.jl leaves those columns numeric and skips translation for them,
which means a weighted analysis works on the frame as returned.

The cost is that reserved codes stay in the column as numbers. See
[Value translation](@ref) for how to find and filter them.

Component names accept the R short forms:

- `:DEMO` or `:Demographics`
- `:DIET` or `:Dietary`
- `:EXAM` or `:Examination`
- `:LAB` or `:Laboratory`
- `:Q` or `:Questionnaire`
