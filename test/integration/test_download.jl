@testitem "Download integration" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "download DEMO_J" begin
        # A throwaway cache root, so the fresh-download path never wipes a real cache
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                NHANES.clear_cache()

                df = NHANES.download("DEMO_J")

                @test df isa DataFrames.DataFrame

                @test "SEQN" in names(df)
                @test "RIAGENDR" in names(df)  # Gender
                @test "RIDAGEYR" in names(df)  # Age in years

                @test DataFrames.nrow(df) > 1000

                @test NHANES.is_cached("DEMO_J")

                # Second download should use cache (fast)
                df2 = NHANES.download("DEMO_J")
                @test DataFrames.nrow(df2) == DataFrames.nrow(df)
            end
        end
    end

    @testset "download with force refresh" begin
        df = NHANES.download("DEMO_J"; force = true)
        @test df isa DataFrames.DataFrame
    end

    @testset "continuous variables stay numeric" begin
        demo = NHANES.download("DEMO_J")

        # Age and the survey weights are measurements, not codes
        @test eltype(demo.RIDAGEYR) <: Union{Real, Missing}
        @test eltype(demo.WTMEC2YR) <: Union{Real, Missing}
        @test eltype(demo.WTINT2YR) <: Union{Real, Missing}
        @test eltype(demo.INDFMPIR) <: Union{Real, Missing}
        @test maximum(skipmissing(demo.RIDAGEYR)) == 80

        bmx = NHANES.download("BMX_J")
        for col in [:BMXWT, :BMXHT, :BMXBMI]
            @test eltype(bmx[!, col]) <: Union{Real, Missing}
        end
    end

    @testset "categorical variables are translated" begin
        demo = NHANES.download("DEMO_J")

        @test eltype(demo.RIAGENDR) <: Union{String, Missing}
        @test Set(skipmissing(demo.RIAGENDR)) == Set(["Male", "Female"])
    end

    @testset "download invalid table" begin
        @test_throws NHANES.TableNotFoundError NHANES.download("INVALID_TABLE_XYZ")
    end
end
