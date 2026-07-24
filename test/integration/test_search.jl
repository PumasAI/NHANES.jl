@testitem "Variable search" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "search for gender" begin
        results =
            NHANES.search("gender"; component = :Demographics, years = 2017)

        @test results isa DataFrames.DataFrame
        @test "variable" in names(results)
        @test "description" in names(results)
        @test "table" in names(results)
    end
end

@testitem "search_var_name" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "exact variable name search" begin
        results = NHANES.search_var_name("BMXLEG"; years = 2005)

        @test results isa DataFrames.DataFrame
        @test "variable" in names(results)
        @test "table" in names(results)
        @test DataFrames.nrow(results) > 0
        @test all(uppercase.(results.variable) .== "BMXLEG")
    end

    @testset "case insensitive" begin
        upper = NHANES.search_var_name("BMXLEG"; years = 2005)
        lower = NHANES.search_var_name("bmxleg"; years = 2005)
        @test DataFrames.nrow(upper) == DataFrames.nrow(lower)
    end
end

@testitem "search_table_names" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "table name pattern search" begin
        results = NHANES.search_table_names("BMX"; years = 2005)

        @test results isa DataFrames.DataFrame
        @test "name" in names(results)
        @test "description" in names(results)
        @test DataFrames.nrow(results) > 0
        @test all(occursin.(r"BMX"i, results.name))
    end

    @testset "filter by component" begin
        results = NHANES.search_table_names(
            "BMX";
            component = :Examination,
            years = 2005,
        )
        @test all(results.component .== "Examination")
    end

    @testset "includes pre-pandemic P_ tables" begin
        results = NHANES.search_table_names("BMX")
        @test "P_BMX" in results.name
    end
end

@testitem "Pre-pandemic tables" tags = [:integration] begin
    import NHANES
    import DataFrames

    @testset "tables(:Examination, :P)" begin
        tbls = NHANES.tables(:Examination, :P)
        @test tbls isa DataFrames.DataFrame
        @test "P_BMX" in tbls.name
    end

    @testset "download P_BMX" begin
        df = NHANES.download("P_BMX")
        @test df isa DataFrames.DataFrame
        @test DataFrames.nrow(df) > 0
        @test :SEQN in propertynames(df)
    end
end
