@testitem "Variables listing" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "variables for DEMO_J" begin
        df = NHANES.variables("DEMO_J")

        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
        @test "name" in names(df)
        @test "label" in names(df)

        @test any(n -> occursin("SEQN", n), df.name)
    end
end
