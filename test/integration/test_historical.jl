@testitem "Historical tables listing" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "$survey lists data files" for survey in NHANES.HISTORICAL_SURVEYS
        df = NHANES.historical_tables(survey)

        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
        @test names(df) == ["name", "description", "url"]
        @test !any(occursin.(r"readme"i, df.name))
        @test all(startswith.(df.url, "http"))
    end
end

@testitem "Historical transport file download" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "NHANES III serology file reads as a table" begin
        df = NHANES.historical_download(:nhanes3, "SSNH3MGM")

        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
        @test "SEQN" in names(df)
    end

    @testset "fixed-width files are refused" begin
        @test_throws ArgumentError NHANES.historical_download(:nhanes1, "DU4111")
    end

    @testset "unlisted name" begin
        @test_throws NHANES.TableNotFoundError NHANES.historical_download(
            :nhanes3,
            "NOSUCHFILE",
        )
    end
end

@testitem "Historical file download" tags = [:integration] begin
    import NHANES

    @testset "NHANES I fixed-width file lands in the cache" begin
        path = NHANES.historical_file(:nhanes1, "DU4111")

        @test isfile(path)
        @test endswith(path, "DU4111.txt")
        @test filesize(path) > 0
    end

    @testset "unlisted name" begin
        @test_throws NHANES.TableNotFoundError NHANES.historical_file(
            :nhanes1,
            "NOSUCHFILE",
        )
    end
end
