@testitem "Translate columns" tags = [:unit] setup = [CodebookFixtures] begin
    import NHANES
    import DataFrames

    @testset "categorical column" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "DEMO_T",
                    "codebook_categorical.html",
                )

                df = DataFrames.DataFrame(
                    RIAGENDR = Union{Float64, Missing}[1, 2, missing],
                )
                NHANES.translate!(df, "DEMO_T", :RIAGENDR)

                @test isequal(df.RIAGENDR, ["Male", "Female", missing])
            end
        end
    end

    @testset "several columns" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "DEMO_T",
                    "codebook_categorical.html",
                )

                df = DataFrames.DataFrame(
                    RIAGENDR = Union{Float64, Missing}[1, 2],
                    DMDMARTL = Union{Float64, Missing}[3, 99],
                )
                NHANES.translate!(df, "DEMO_T", [:RIAGENDR, :DMDMARTL])

                @test df.RIAGENDR == ["Male", "Female"]
                @test df.DMDMARTL == ["Divorced", "Don't know"]
            end
        end
    end

    @testset "continuous variable is rejected" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "BMX_T",
                    "codebook_continuous.html",
                )

                df = DataFrames.DataFrame(BMXWT = Union{Float64, Missing}[70.5])
                @test_throws ArgumentError NHANES.translate!(df, "BMX_T", :BMXWT)

                # The column survives the rejected call unchanged
                @test df.BMXWT == [70.5]
            end
        end
    end

    @testset "variable absent from the codebook" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "DEMO_T",
                    "codebook_categorical.html",
                )

                df = DataFrames.DataFrame(SEQN = Union{Float64, Missing}[1])
                @test_throws NHANES.MetadataError NHANES.translate!(
                    df,
                    "DEMO_T",
                    :SEQN,
                )
            end
        end
    end

    @testset "non-mutating translate leaves the source alone" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "DEMO_T",
                    "codebook_categorical.html",
                )

                df = DataFrames.DataFrame(
                    RIAGENDR = Union{Float64, Missing}[1, 2],
                )
                out = NHANES.translate(df, "DEMO_T", :RIAGENDR)

                @test df.RIAGENDR == [1.0, 2.0]
                @test eltype(df.RIAGENDR) == Union{Float64, Missing}
                @test out.RIAGENDR == ["Male", "Female"]
            end
        end
    end
end
