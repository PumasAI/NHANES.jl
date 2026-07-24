@testitem "DXA data" tags = [:unit] begin
    import NHANES

    @testset "DXA_YEARS constant" begin
        @test 1999 in NHANES.DXA_YEARS
        @test 2005 in NHANES.DXA_YEARS
        @test !(2007 in NHANES.DXA_YEARS)
    end

    @testset "dxa_tables" begin
        df = NHANES.dxa_tables(2005)
        @test "DXX_D" in df.name

        @test_throws ArgumentError NHANES.dxa_tables(2007)
    end

    @testset "dxa_tables suppl" begin
        df = NHANES.dxa_tables(2005; suppl = true)
        @test "DXX_D_S" in df.name
        @test occursin("Highly Variable", df.description[1])
    end

    @testset "table names follow the cycle suffix" begin
        @test NHANES._dxa_table_name(1999, false) == "DXX"
        @test NHANES._dxa_table_name(1999, true) == "DXX_S"
        @test NHANES._dxa_table_name(2005, false) == "DXX_D"
        @test NHANES._dxa_table_name(2005, true) == "DXX_D_S"
    end

    @testset "data files live under the cycle year" begin
        @test NHANES._dxa_url(1999, false) ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/1999/DataFiles/dxx.xpt"
        @test NHANES._dxa_url(1999, true) ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/1999/DataFiles/dxx_s.xpt"
        @test NHANES._dxa_url(2005, false) ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2005/DataFiles/dxx_d.xpt"
        @test NHANES._dxa_url(2005, true) ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2005/DataFiles/dxx_d_s.xpt"
    end

    @testset "invalid year" begin
        @test_throws ArgumentError NHANES.dxa(2007)
    end
end
