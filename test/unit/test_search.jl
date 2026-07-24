@testitem "_all_cycles" tags = [:unit] begin
    import NHANES

    cycles = NHANES._all_cycles()
    years = collect(Int, filter(c -> c isa Int, cycles))

    @testset "cycles come back in survey order" begin
        @test years == NHANES.survey_years()
    end

    @testset "pre-pandemic cycle is included" begin
        @test NHANES.PREPANDEMIC_CYCLE in cycles
    end

    @testset "unpublished 2019 cycle is absent" begin
        @test !(2019 in years)
    end
end

@testitem "_skip_missing" tags = [:unit] begin
    import NHANES

    @testset "a missing page is skipped" begin
        @test NHANES._skip_missing(
            () -> throw(NHANES.DownloadError("u", "not found", 404)),
        ) === nothing
    end

    @testset "a server failure propagates" begin
        @test_throws NHANES.DownloadError NHANES._skip_missing(
            () -> throw(NHANES.DownloadError("u", "server error", 500)),
        )
    end

    @testset "a connection failure propagates" begin
        @test_throws NHANES.DownloadError NHANES._skip_missing(
            () -> throw(NHANES.DownloadError("u", "no route to host", nothing)),
        )
    end

    @testset "an unrelated failure propagates" begin
        @test_throws BoundsError NHANES._skip_missing(() -> [][1])
    end

    @testset "a result passes through" begin
        @test NHANES._skip_missing(() -> 42) == 42
    end
end

@testitem "_fetch_pages" tags = [:unit] begin
    import NHANES

    components = [:Demographics, :Laboratory]
    cycles = Union{Int, Symbol}[2015, 2017, :P]
    requests = [(comp, cycle) for comp in components for cycle in cycles]

    @testset "results keep request order when fetches finish out of order" begin
        pages = NHANES._fetch_pages(components, cycles) do comp, cycle
            position = findfirst(==((comp, cycle)), requests)
            sleep(0.01 * (length(requests) - position))
            return (comp, cycle)
        end

        @test [(comp, cycle) for (comp, cycle, _) in pages] == requests
        @test [page for (_, _, page) in pages] == requests
    end

    @testset "fetches run concurrently up to the limit" begin
        inflight = Ref(0)
        peak = Ref(0)

        pages = NHANES._fetch_pages(components, 1:20) do comp, cycle
            inflight[] += 1
            peak[] = max(peak[], inflight[])
            sleep(0.005)
            inflight[] -= 1
            return (comp, cycle)
        end

        @test length(pages) == 40
        @test peak[] == NHANES.SEARCH_CONCURRENCY
    end

    @testset "a missing page is dropped" begin
        pages = NHANES._fetch_pages(components, cycles) do comp, cycle
            cycle == 2015 && throw(NHANES.DownloadError("u", "not found", 404))
            return (comp, cycle)
        end

        @test [(comp, cycle) for (comp, cycle, _) in pages] ==
            filter(r -> r[2] != 2015, requests)
    end

    @testset "a server failure propagates unwrapped" begin
        @test_throws NHANES.DownloadError NHANES._fetch_pages(
            components,
            cycles,
        ) do comp, cycle
            throw(NHANES.DownloadError("u", "server error", 500))
        end
    end

    @testset "an unrelated failure propagates unwrapped" begin
        @test_throws BoundsError NHANES._fetch_pages(
            components,
            cycles,
        ) do comp, cycle
            return [][1]
        end
    end

    @testset "a failure stops the remaining fetches" begin
        fetched = Ref(0)

        @test_throws NHANES.DownloadError NHANES._fetch_pages(
            components,
            1:20,
        ) do comp, cycle
            cycle == 1 && throw(NHANES.DownloadError("u", "server error", 500))
            fetched[] += 1
            return (comp, cycle)
        end

        @test fetched[] < 40
    end
end

@testsnippet CachedVariableList begin
    import NHANES

    const VARIABLES = [
        Dict{String, Any}(
            "name" => "RIAGENDR",
            "description" => "Gender of the participant.",
            "table" => "DEMO_J",
            "table_description" => "Demographic Variables and Sample Weights",
        ),
        Dict{String, Any}(
            "name" => "RIDAGEYR",
            "description" => "Age in years of the participant.",
            "table" => "DEMO_J",
            "table_description" => "Demographic Variables and Sample Weights",
        ),
    ]

    """Run `f` with every 2017 variable list served from a throwaway cache."""
    function with_cached_2017(f)
        return mktempdir() do dir
            NHANES.with_cache_dir(dir) do
                for component in NHANES.COMPONENTS
                    entries =
                        component === :Demographics ? VARIABLES : Dict{String, Any}[]
                    NHANES.save_metadata(
                        "variablelist",
                        "$(component)_2017",
                        entries,
                    )
                    NHANES.save_metadata(
                        "tables",
                        "$(component)_2017",
                        [
                            Dict{String, Any}(
                                    "name" => e["table"],
                                    "description" => e["table_description"],
                                ) for e in entries
                        ],
                    )
                end
                return f()
            end
        end
    end
end

@testitem "search" tags = [:unit] setup = [CachedVariableList] begin
    import NHANES
    import DataFrames

    with_cached_2017() do
        @testset "matches on description" begin
            results =
                NHANES.search("gender"; component = :Demographics, years = 2017)
            @test DataFrames.nrow(results) == 1
            @test results.variable == ["RIAGENDR"]
            @test results.cycle == [2017]
        end

        @testset "reports the cycle, not the year" begin
            results =
                NHANES.search("gender"; component = :Demographics, years = 2017)
            @test names(results) ==
                ["variable", "description", "table", "component", "cycle"]
        end

        @testset "no match gives an empty frame" begin
            results = NHANES.search(
                "no such variable";
                component = :Demographics,
                years = 2017,
            )
            @test DataFrames.nrow(results) == 0
        end

        @testset "force is accepted" begin
            results = NHANES.search(
                "gender";
                component = :Demographics,
                years = 2017,
                force = false,
            )
            @test DataFrames.nrow(results) == 1
        end
    end
end

@testitem "search_var_name" tags = [:unit] setup = [CachedVariableList] begin
    import NHANES
    import DataFrames

    with_cached_2017() do
        @testset "exact match is case-insensitive" begin
            results = NHANES.search_var_name("riagendr"; years = 2017)
            @test results.variable == ["RIAGENDR"]
            @test results.table == ["DEMO_J"]
            @test results.cycle == [2017]
        end

        @testset "partial name does not match" begin
            @test DataFrames.nrow(NHANES.search_var_name("RIA"; years = 2017)) == 0
        end
    end
end

@testitem "search_table_names" tags = [:unit] setup = [CachedVariableList] begin
    import NHANES
    import DataFrames

    with_cached_2017() do
        @testset "matches on table name" begin
            results = NHANES.search_table_names("DEMO"; years = 2017)
            @test results.name == ["DEMO_J"]
            @test results.description ==
                ["Demographic Variables and Sample Weights"]
            @test results.cycle == [2017]
        end

        @testset "no match gives an empty frame" begin
            @test DataFrames.nrow(
                NHANES.search_table_names("NOSUCH"; years = 2017),
            ) == 0
        end
    end
end

@testsnippet CachedEveryCycle begin
    import NHANES

    """Run `f` with a variable list cached for every component and cycle."""
    function with_cached_cycles(f)
        return mktempdir() do dir
            NHANES.with_cache_dir(dir) do
                for component in NHANES.COMPONENTS, cycle in NHANES._all_cycles()
                    key = "$(component)_$(cycle)"
                    NHANES.save_metadata(
                        "variablelist",
                        key,
                        [
                            Dict{String, Any}(
                                "name" => "GLU_$(key)",
                                "description" => "Glucose measure.",
                                "table" => "TBL_$(key)",
                                "table_description" => "Glucose table.",
                            ),
                            Dict{String, Any}(
                                "name" => "LBXGLU",
                                "description" => "Glucose measure.",
                                "table" => "TBL_$(key)",
                                "table_description" => "Glucose table.",
                            ),
                        ],
                    )
                    NHANES.save_metadata(
                        "tables",
                        key,
                        [
                            Dict{String, Any}(
                                "name" => "TBL_$(key)",
                                "description" => "Glucose table.",
                            ),
                        ],
                    )
                end
                return f()
            end
        end
    end

    """Every component and cycle pair, in the order a search reports them."""
    const KEYS = [
        "$(component)_$(cycle)" for component in NHANES.COMPONENTS
            for cycle in NHANES._all_cycles()
    ]
end

@testitem "search result order" tags = [:unit] setup = [CachedEveryCycle] begin
    import NHANES

    with_cached_cycles() do
        @testset "search runs component by component, cycle by cycle" begin
            expected = reduce(vcat, [["GLU_$k", "LBXGLU"] for k in KEYS])
            runs = [NHANES.search("glucose").variable for _ in 1:5]
            @test all(==(expected), runs)
        end

        @testset "search_var_name keeps its order" begin
            runs = [NHANES.search_var_name("lbxglu").table for _ in 1:5]
            @test all(==(["TBL_$k" for k in KEYS]), runs)
        end

        @testset "search_table_names keeps its order" begin
            runs = [NHANES.search_table_names("TBL").name for _ in 1:5]
            @test all(==(["TBL_$k" for k in KEYS]), runs)
        end
    end
end
