@testitem "table_rows" tags = [:unit] begin
    import NHANES

    @testset "plain cells" begin
        rows = NHANES.table_rows("<table><tr><td>SEQN</td><td>DEMO_J</td></tr></table>")
        @test rows == [["SEQN", "DEMO_J"]]
    end

    @testset "nested inline markup adds no whitespace" begin
        rows = NHANES.table_rows(
            "<table><tr><td>Weight in <b>kg</b>, measured</td></tr></table>",
        )
        @test rows == [["Weight in kg, measured"]]
    end

    @testset "whitespace between markup is preserved" begin
        rows = NHANES.table_rows(
            "<table><tr><td>Blood <i>pressure</i></td></tr></table>",
        )
        @test rows == [["Blood pressure"]]
    end

    @testset "header rows have no cells" begin
        rows = NHANES.table_rows(
            "<table><thead><tr><th>Name</th></tr></thead>" *
                "<tbody><tr><td>SEQN</td></tr></tbody></table>",
        )
        @test rows == [String[], ["SEQN"]]
    end

    @testset "each row appears once" begin
        rows = NHANES.table_rows(
            "<table><tbody><tr><td>a</td></tr><tr><td>b</td></tr></tbody></table>",
        )
        @test rows == [["a"], ["b"]]
    end
end

@testitem "parse_variablelist_html" tags = [:unit] begin
    import NHANES

    html = read(
        joinpath(@__DIR__, "..", "fixtures", "variablelist_demographics_2017.html"),
        String,
    )
    vars = NHANES.parse_variablelist_html(html)

    @testset "one entry per data row" begin
        @test length(vars) == 5
    end

    @testset "columns map to name, description and table" begin
        first = vars[1]
        @test first["name"] == "AIALANGA"
        @test first["description"] ==
            "Language of the MEC ACASI Interview Instrument"
        @test first["table"] == "DEMO_J"
        @test first["table_description"] ==
            "Demographic Variables and Sample Weights"
    end

    @testset "header row is not a variable" begin
        @test !any(v -> v["name"] == "Variable Name", vars)
    end

    @testset "rows are not reported twice" begin
        @test length(unique(v["name"] for v in vars)) == length(vars)
    end
end
