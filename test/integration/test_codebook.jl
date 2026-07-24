@testitem "Codebook access" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "codebook for RIAGENDR" begin
        cb = NHANES.codebook("DEMO_J", :RIAGENDR)

        @test cb isa DataFrames.DataFrame
        @test names(cb) == ["code", "label", "count"]
        @test eltype(cb.code) == String
        @test eltype(cb.count) == Int

        @test cb.code[1:2] == ["1", "2"]
        @test cb.label[1:2] == ["Male", "Female"]
        @test cb.count[1] > 4000
        @test cb.count[2] > 4000
        @test sum(cb.count) == DataFrames.nrow(NHANES.download("DEMO_J"))
    end

    @testset "codebook for a continuous variable" begin
        cb = NHANES.codebook("BMX_J", :BMXWT)

        # The published range, not one row per observed weight
        @test DataFrames.nrow(cb) < 10
        @test occursin(" to ", cb.code[1])
        @test cb.label[1] == "Range of Values"
        @test sum(cb.count) == DataFrames.nrow(NHANES.download("BMX_J"))
    end
end
