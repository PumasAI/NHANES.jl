@testitem "Value translation" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "translate! gender column" begin
        demo = NHANES.download("DEMO_J"; translate = false)
        @test eltype(demo.RIAGENDR) <: Union{Real, Missing}

        NHANES.translate!(demo, "DEMO_J", :RIAGENDR)

        @test eltype(demo.RIAGENDR) <: Union{String, Missing}
        @test Set(skipmissing(demo.RIAGENDR)) == Set(["Male", "Female"])
    end

    @testset "translate non-mutating" begin
        demo = NHANES.download("DEMO_J"; translate = false)
        codes = copy(demo.RIAGENDR)

        demo2 = NHANES.translate(demo, "DEMO_J", :RIAGENDR)

        # The source keeps its codes; only the copy is labelled
        @test isequal(demo.RIAGENDR, codes)
        @test eltype(demo2.RIAGENDR) <: Union{String, Missing}
    end

    @testset "translate! rejects a continuous variable" begin
        bmx = NHANES.download("BMX_J"; translate = false)
        @test_throws ArgumentError NHANES.translate!(bmx, "BMX_J", :BMXWT)
        @test eltype(bmx.BMXWT) <: Union{Real, Missing}
    end
end
