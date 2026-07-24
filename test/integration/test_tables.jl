@testitem "Tables listing" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "tables for continuous NHANES" begin
        df = NHANES.tables(:Demographics, 2017)

        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0

        @test "name" in names(df)
        @test "description" in names(df)

        @test any(occursin("DEMO", n) for n in df.name)
    end

    @testset "tables for Laboratory" begin
        df = NHANES.tables(:Laboratory, 2017)

        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
    end

    @testset "invalid component" begin
        @test_throws ArgumentError NHANES.tables(:InvalidComponent, 2017)
    end

    @testset "invalid year" begin
        @test_throws ArgumentError NHANES.tables(:Demographics, 1990)
    end
end
