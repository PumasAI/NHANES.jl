@testitem "DXA download" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "download DXA 2005" begin
        df = NHANES.dxa(2005)
        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
    end

    @testset "download DXA suppl" begin
        df = NHANES.dxa(2005; suppl = true)
        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
    end

    @testset "download DXA 1999" begin
        df = NHANES.dxa(1999)
        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
    end
end
