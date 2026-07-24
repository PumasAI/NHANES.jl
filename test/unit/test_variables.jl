@testitem "_parse_variables_from_codebook" tags = [:unit] begin
    import NHANES

    html = """
    <html><body>
      <h3 class="vartitle" id="SEQN">SEQN - Respondent sequence number</h3>
      <h3 class="vartitle" id="RIAGENDR">RIAGENDR - Gender</h3>
      <h3>Codebook and Frequencies</h3>
    </body></html>
    """

    vars = NHANES._parse_variables_from_codebook(html)

    @testset "variable headers split on the separator" begin
        @test [v["name"] for v in vars] == ["SEQN", "RIAGENDR"]
        @test [v["label"] for v in vars] ==
            ["Respondent sequence number", "Gender"]
    end
end

@testitem "_variables_to_dataframe" tags = [:unit] begin
    import NHANES
    import DataFrames

    @testset "empty input" begin
        df = NHANES._variables_to_dataframe(Dict{String, Any}[])
        @test DataFrames.nrow(df) == 0
        @test names(df) == ["name", "label"]
    end

    @testset "missing label becomes empty" begin
        df = NHANES._variables_to_dataframe([Dict("name" => "SEQN")])
        @test df.label == [""]
    end
end
