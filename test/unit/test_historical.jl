@testitem "Historical surveys" tags = [:unit] begin
    import NHANES

    @testset "HISTORICAL_SURVEYS constant" begin
        @test :nhanes1 in NHANES.HISTORICAL_SURVEYS
        @test :nhanes2 in NHANES.HISTORICAL_SURVEYS
        @test :nhanes3 in NHANES.HISTORICAL_SURVEYS
    end

    @testset "invalid survey" begin
        @test_throws ArgumentError NHANES.historical_tables(:nhanes4)
    end

    @testset "listing page URLs" begin
        @test NHANES._historical_tables_url(:nhanes1) ==
            "https://wwwn.cdc.gov/nchs/nhanes/nhanes1/default.aspx"
        @test NHANES._historical_tables_url(:nhanes3) ==
            "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/datafiles.aspx"
    end
end

@testitem "_parse_historical_tables" tags = [:unit] begin
    import NHANES

    """Data files parsed from a saved copy of a survey's listing page."""
    function parsed(survey, fixture)
        html = read(joinpath(@__DIR__, "..", "fixtures", fixture), String)
        url = NHANES._historical_tables_url(survey)
        return NHANES._parse_historical_tables(html, url)
    end

    nhanes3 = parsed(:nhanes3, "historical_nhanes3_datafiles.html")
    nhanes1 = parsed(:nhanes1, "historical_nhanes1_default.html")

    @testset "NHANES III data files" begin
        @test [d["name"] for d in nhanes3] ==
            ["ADULT", "LAB", "VID_NH3", "RXQ_DRUG"]
        @test nhanes3[1]["url"] ==
            "https://wwwn.cdc.gov/nchs/data/nhanes3/1a/adult.dat"
        @test nhanes3[4]["url"] ==
            "http://wwwn.cdc.gov/nchs/nhanes/1999-2000/RXQ_DRUG.xpt"
    end

    @testset "readme files are not data tables" begin
        @test !any(d -> occursin(r"readme"i, d["name"]), nhanes3)
    end

    @testset "NHANES I data files" begin
        @test [d["name"] for d in nhanes1] == ["DU4111", "NH1ECG", "GROWTHCH"]
        @test nhanes1[3]["url"] ==
            "https://wwwn.cdc.gov/nchs/data/nhes123/growthch.xpt"
    end

    @testset "documentation and code links are skipped" begin
        @test !any(
            d -> endswith(d["url"], ".pdf") || endswith(d["url"], ".sas"),
            nhanes1,
        )
    end

    @testset "plain relative link does not throw" begin
        data = NHANES._parse_historical_tables(
            """<a href="data/foo.xpt">x</a>""",
            "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/datafiles.aspx",
        )
        @test length(data) == 1
        @test data[1]["url"] ==
            "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/data/foo.xpt"
    end
end

@testitem "_historical_entry" tags = [:unit] begin
    import NHANES

    """Listing DataFrame built from a saved copy of a survey's listing page."""
    function listing(survey, fixture)
        html = read(joinpath(@__DIR__, "..", "fixtures", fixture), String)
        url = NHANES._historical_tables_url(survey)
        return NHANES._tables_to_dataframe(
            NHANES._parse_historical_tables(html, url),
        )
    end

    nhanes1 = listing(:nhanes1, "historical_nhanes1_default.html")
    nhanes3 = listing(:nhanes3, "historical_nhanes3_datafiles.html")

    @testset "transport file" begin
        entry = NHANES._historical_entry(:nhanes3, nhanes3, "VID_NH3")
        @test entry.name == "VID_NH3"
        @test entry.url ==
            "https://wwwn.cdc.gov/nchs/data/nhanes3/2a/VID_NH3.xpt"
        @test entry.extension == ".xpt"
    end

    @testset "fixed-width file" begin
        entry = NHANES._historical_entry(:nhanes1, nhanes1, "DU4111")
        @test entry.url ==
            "https://wwwn.cdc.gov/nchs/data/nhanes1/DU4111.txt"
        @test entry.extension == ".txt"
        @test NHANES._historical_entry(:nhanes1, nhanes1, "NH1ECG").extension ==
            ".dat"
    end

    @testset "lookup ignores case" begin
        @test NHANES._historical_entry(:nhanes1, nhanes1, "du4111").name ==
            "DU4111"
    end

    @testset "unlisted name" begin
        @test_throws NHANES.TableNotFoundError NHANES._historical_entry(
            :nhanes1,
            nhanes1,
            "NOSUCH",
        )
        @test_throws "historical_tables(:nhanes1)" NHANES._historical_entry(
            :nhanes1,
            nhanes1,
            "NOSUCH",
        )
    end

    @testset "transport files only" begin
        transport = NHANES._historical_entry(:nhanes1, nhanes1, "GROWTHCH")
        fixed_width = NHANES._historical_entry(:nhanes1, nhanes1, "DU4111")

        @test NHANES._require_transport_file(transport) === nothing
        @test_throws ArgumentError NHANES._require_transport_file(fixed_width)
        @test_throws "historical_file" NHANES._require_transport_file(
            fixed_width,
        )
    end
end

@testitem "_historical_cache_path" tags = [:unit] begin
    import NHANES

    mktempdir() do root
        NHANES.with_cache_dir(root) do
            @testset "the published extension is preserved" begin
                path = NHANES._historical_cache_path(:nhanes1, "DU4111", ".txt")
                @test basename(path) == "DU4111.txt"
                @test isdir(dirname(path))
            end

            @testset "surveys keep separate directories" begin
                @test dirname(
                    NHANES._historical_cache_path(:nhanes1, "ADULT", ".dat"),
                ) != dirname(
                    NHANES._historical_cache_path(:nhanes3, "ADULT", ".dat"),
                )
            end

            @testset "names that could escape the cache are rejected" begin
                for bad in ["../../etc/passwd", "DU/../X", "DU 4111", ""]
                    @test_throws ArgumentError NHANES._historical_cache_path(
                        :nhanes1,
                        bad,
                        ".txt",
                    )
                end
            end

            @testset "extensions CDC does not publish are rejected" begin
                for bad in [".sas", "/../evil", ".xpt.sh", ""]
                    @test_throws ArgumentError NHANES._historical_cache_path(
                        :nhanes1,
                        "DU4111",
                        bad,
                    )
                end
            end
        end
    end
end
