@testitem "Format code for label lookup" tags = [:unit] begin
    import NHANES

    @test NHANES._format_code(1.0) == "1"
    @test NHANES._format_code(2) == "2"
    @test NHANES._format_code(4.98) == "4.98"
    @test NHANES._format_code("A") == "A"
end

@testitem "Apply labels" tags = [:unit] setup = [CodebookFixtures] begin
    import NHANES
    import DataFrames

    @testset "categorical columns become labels" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "DEMO_T",
                    "codebook_categorical.html",
                )

                df = DataFrames.DataFrame(
                    RIAGENDR = Union{Float64, Missing}[1, 2, missing],
                    DMDMARTL = Union{Float64, Missing}[1, 77, missing],
                )
                NHANES._apply_labels!(df, "DEMO_T")

                @test isequal(df.RIAGENDR, ["Male", "Female", missing])
                @test isequal(df.DMDMARTL, ["Married", "Refused", missing])
            end
        end
    end

    @testset "continuous columns keep their numeric type" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "BMX_T",
                    "codebook_continuous.html",
                )

                df = DataFrames.DataFrame(
                    BMXWT = Union{Float64, Missing}[70.5, 82.1, missing],
                    BMXBMI = Union{Float64, Missing}[24.2, missing, 31.0],
                )
                NHANES._apply_labels!(df, "BMX_T")

                @test eltype(df.BMXWT) == Union{Float64, Missing}
                @test df.BMXWT[1] == 70.5
                @test eltype(df.BMXBMI) == Union{Float64, Missing}
            end
        end
    end

    @testset "survey weights and ages stay numeric" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables("DEMO_T", "codebook_mixed.html")

                df = DataFrames.DataFrame(
                    RIDAGEYR = Union{Float64, Missing}[3, 80, missing],
                    WTMEC2YR = Union{Float64, Missing}[0, 12345.678, missing],
                )
                NHANES._apply_labels!(df, "DEMO_T")

                @test eltype(df.RIDAGEYR) == Union{Float64, Missing}
                @test eltype(df.WTMEC2YR) == Union{Float64, Missing}
                @test df.WTMEC2YR[2] == 12345.678
            end
        end
    end

    @testset "unmatched categorical codes warn once" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "DEMO_T",
                    "codebook_categorical.html",
                )

                df = DataFrames.DataFrame(
                    RIAGENDR = Union{Float64, Missing}[1, 3, 3, 4],
                )
                @test_logs (:warn, r"no codebook label") match_mode = :any begin
                    NHANES._apply_labels!(df, "DEMO_T")
                end

                @test df.RIAGENDR == ["Male", "3.0", "3.0", "4.0"]
            end
        end
    end

    @testset "columns absent from the codebook are untouched" begin
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                CodebookFixtures.prime_value_tables(
                    "DEMO_T",
                    "codebook_categorical.html",
                )

                df = DataFrames.DataFrame(SEQN = Union{Float64, Missing}[1, 2])
                NHANES._apply_labels!(df, "DEMO_T")
                @test eltype(df.SEQN) == Union{Float64, Missing}
            end
        end
    end
end
