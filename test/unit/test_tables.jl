@testitem "_parse_tables_from_variablelist" tags = [:unit] begin
    import NHANES

    fixture(name) = read(joinpath(@__DIR__, "..", "fixtures", name), String)

    @testset "single data file" begin
        data = NHANES._parse_tables_from_variablelist(
            fixture("variablelist_demographics_2017.html"),
        )
        @test length(data) == 1
        @test data[1]["name"] == "DEMO_J"
        @test data[1]["description"] == "Demographic Variables and Sample Weights"
    end

    @testset "one entry per data file" begin
        data = NHANES._parse_tables_from_variablelist(
            fixture("variablelist_examination_2017.html"),
        )
        @test [d["name"] for d in data] ==
            ["BPX_J", "BMX_J", "OHXDEN_J", "OHXREF_J"]
        @test data[2]["description"] == "Body Measures"
    end
end

@testitem "_tables_to_dataframe" tags = [:unit] begin
    import NHANES
    import DataFrames

    @testset "empty input" begin
        df = NHANES._tables_to_dataframe(Dict{String, Any}[])
        @test DataFrames.nrow(df) == 0
        @test names(df) == ["name", "description"]
    end

    @testset "url column appears when present" begin
        df = NHANES._tables_to_dataframe(
            [Dict("name" => "ADULT", "description" => "", "url" => "u")],
        )
        @test names(df) == ["name", "description", "url"]
    end
end
