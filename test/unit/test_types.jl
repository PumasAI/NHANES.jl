@testitem "Exception types" tags = [:unit] begin
    import NHANES

    @testset "NHANESError hierarchy" begin
        @test NHANES.TableNotFoundError <: NHANES.NHANESError
        @test NHANES.DownloadError <: NHANES.NHANESError
        @test NHANES.MetadataError <: NHANES.NHANESError
        @test NHANES.NHANESError <: Exception
    end

    @testset "TableNotFoundError" begin
        err = NHANES.TableNotFoundError(
            "DEMO_Z",
            "Table DEMO_Z not found for any survey cycle",
        )
        @test err.table == "DEMO_Z"
        @test err.message == "Table DEMO_Z not found for any survey cycle"

        buf = IOBuffer()
        showerror(buf, err)
        msg = String(take!(buf))
        @test occursin("DEMO_Z", msg)
        @test occursin("not found", msg)
    end

    @testset "DownloadError" begin
        err = NHANES.DownloadError(
            "https://example.com/data.xpt",
            "Connection timeout",
            408,
        )
        @test err.url == "https://example.com/data.xpt"
        @test err.message == "Connection timeout"
        @test err.status == 408

        buf = IOBuffer()
        showerror(buf, err)
        msg = String(take!(buf))
        @test occursin("Connection timeout", msg)
        @test occursin("408", msg)

        err2 = NHANES.DownloadError(
            "https://example.com/data.xpt",
            "Network error",
            nothing,
        )
        @test err2.status === nothing
    end

    @testset "MetadataError" begin
        err = NHANES.MetadataError("codebook", "Failed to parse HTML")
        @test err.source == "codebook"
        @test err.message == "Failed to parse HTML"

        buf = IOBuffer()
        showerror(buf, err)
        msg = String(take!(buf))
        @test occursin("codebook", msg)
        @test occursin("Failed to parse", msg)
    end
end

@testitem "Constants" tags = [:unit] begin
    import NHANES

    @testset "COMPONENTS" begin
        @test :Demographics in NHANES.COMPONENTS
        @test :Laboratory in NHANES.COMPONENTS
        @test :Examination in NHANES.COMPONENTS
        @test :Dietary in NHANES.COMPONENTS
        @test :Questionnaire in NHANES.COMPONENTS
        @test length(NHANES.COMPONENTS) == 5
    end

    @testset "SURVEY_CYCLES" begin
        # Continuous NHANES starts 1999
        @test 1999 in keys(NHANES.SURVEY_CYCLES)
        @test 2017 in keys(NHANES.SURVEY_CYCLES)

        @test NHANES.SURVEY_CYCLES[1999] == ""  # 1999-2000 has no suffix
        @test NHANES.SURVEY_CYCLES[2001] == "_B"
        @test NHANES.SURVEY_CYCLES[2003] == "_C"
        @test NHANES.SURVEY_CYCLES[2017] == "_J"

        # 2019-2020 was never released; CDC skipped the letter K
        @test !haskey(NHANES.SURVEY_CYCLES, 2019)
        @test !("_K" in values(NHANES.SURVEY_CYCLES))
        @test NHANES.SURVEY_CYCLES[2021] == "_L"
    end

    @testset "survey_years" begin
        years = NHANES.survey_years()
        @test years isa Vector{Int}
        @test issorted(years)
        @test years == sort(collect(keys(NHANES.SURVEY_CYCLES)))
        @test first(years) == 1999
        @test 2019 ∉ years
    end
end

@testitem "normalize_component" tags = [:unit] begin
    import NHANES

    @testset "full names" begin
        for comp in NHANES.COMPONENTS
            @test NHANES.normalize_component(comp) === comp
            @test NHANES.normalize_component(
                Symbol(lowercase(String(comp))),
            ) === comp
            @test NHANES.normalize_component(
                Symbol(uppercase(String(comp))),
            ) === comp
        end
    end

    @testset "R-style aliases" begin
        @test NHANES.normalize_component(:DEMO) === :Demographics
        @test NHANES.normalize_component(:demo) === :Demographics
        @test NHANES.normalize_component(:Demo) === :Demographics
        @test NHANES.normalize_component(:DIET) === :Dietary
        @test NHANES.normalize_component(:diet) === :Dietary
        @test NHANES.normalize_component(:EXAM) === :Examination
        @test NHANES.normalize_component(:exam) === :Examination
        @test NHANES.normalize_component(:LAB) === :Laboratory
        @test NHANES.normalize_component(:lab) === :Laboratory
        @test NHANES.normalize_component(:Q) === :Questionnaire
        @test NHANES.normalize_component(:q) === :Questionnaire
    end

    @testset "invalid components" begin
        @test_throws ArgumentError NHANES.normalize_component(:Bloodwork)
        @test_throws ArgumentError NHANES.normalize_component(Symbol(""))
    end
end
