@testmodule CodebookFixtures begin
    import NHANES

    """Read a trimmed CDC codebook page from `test/fixtures`."""
    read_fixture(name) = read(joinpath(@__DIR__, "..", "fixtures", name), String)

    """Parse a fixture page and store it in the metadata cache under `table`."""
    function prime_value_tables(table, name)
        parsed = NHANES._parse_all_value_labels(read_fixture(name))
        NHANES.save_metadata("codebook", "$(table)_valuetables", parsed)
        return parsed
    end
end

@testitem "Codebook row classification" tags = [:unit] begin
    import NHANES

    @testset "range rows" begin
        @test NHANES._is_range_row("3.2 to 242.6", "Range of Values")
        @test NHANES._is_range_row("0 to 79", "Range of Values")
        # A non-numeric code cell marks a range even without the description
        @test NHANES._is_range_row("2566.1838545 to 419762.83649", "")
    end

    @testset "code rows" begin
        @test !NHANES._is_range_row("1", "Male")
        @test !NHANES._is_range_row("80", "80 years of age and over")
        @test !NHANES._is_range_row("2566.18", "Something")
        @test !NHANES._is_range_row(".", "Missing")
    end
end

@testitem "Codebook parsing" tags = [:unit] setup = [CodebookFixtures] begin
    import NHANES

    @testset "categorical variable" begin
        parsed =
            NHANES._parse_all_value_labels(
            CodebookFixtures.read_fixture("codebook_categorical.html"),
        )

        @test Set(keys(parsed)) == Set(["RIAGENDR", "DMDMARTL"])

        gender = parsed["RIAGENDR"]
        @test gender["continuous"] == false
        @test gender["labels"] == Dict("1" => "Male", "2" => "Female")
        # The missing row is not a code and must not be matchable
        @test !haskey(gender["labels"], ".")
        @test [row["code"] for row in gender["rows"]] == ["1", "2", "."]
        @test gender["rows"][3]["label"] == "Missing"
    end

    @testset "special codes stay in the label map" begin
        parsed =
            NHANES._parse_all_value_labels(
            CodebookFixtures.read_fixture("codebook_categorical.html"),
        )

        marital = parsed["DMDMARTL"]
        @test marital["continuous"] == false
        @test marital["labels"]["77"] == "Refused"
        @test marital["labels"]["99"] == "Don't know"
        @test length(marital["labels"]) == 8
    end

    @testset "continuous variable" begin
        parsed =
            NHANES._parse_all_value_labels(
            CodebookFixtures.read_fixture("codebook_continuous.html"),
        )

        weight = parsed["BMXWT"]
        @test weight["continuous"] == true
        # Neither the range row nor the missing row is a code
        @test isempty(weight["labels"])
        @test [row["code"] for row in weight["rows"]] == ["3.2 to 242.6", "."]

        @test parsed["BMXBMI"]["continuous"] == true
    end

    @testset "character variable" begin
        parsed =
            NHANES._parse_all_value_labels(
            CodebookFixtures.read_fixture("codebook_character.html"),
        )

        sleep_time = parsed["SLQ300"]
        # Recorded clock times are values, not codes
        @test sleep_time["continuous"] == true
        @test sleep_time["labels"] ==
            Dict("77777" => "Refused", "99999" => "Don't know")
        @test [row["code"] for row in sleep_time["rows"]] == [
            "Usual sleep time on weekdays or workdays",
            "77777",
            "99999",
            "< blank >",
        ]
    end

    @testset "range mixed with special codes" begin
        parsed =
            NHANES._parse_all_value_labels(
            CodebookFixtures.read_fixture("codebook_mixed.html"),
        )

        age = parsed["RIDAGEYR"]
        @test age["continuous"] == true
        @test age["labels"] == Dict("80" => "80 years of age and over")
        @test [row["code"] for row in age["rows"]] == ["0 to 79", "80", "."]

        weight = parsed["WTMEC2YR"]
        @test weight["continuous"] == true
        @test weight["labels"] == Dict("0" => "Not MEC Examined")
    end
end

@testitem "Codebook build from data" tags = [:unit] setup = [CodebookFixtures] begin
    import NHANES
    import DataFrames

    categorical =
        NHANES._parse_all_value_labels(
        CodebookFixtures.read_fixture("codebook_categorical.html"),
    )
    continuous =
        NHANES._parse_all_value_labels(
        CodebookFixtures.read_fixture("codebook_continuous.html"),
    )
    mixed = NHANES._parse_all_value_labels(
        CodebookFixtures.read_fixture("codebook_mixed.html"),
    )

    @testset "categorical counts" begin
        df = DataFrames.DataFrame(
            RIAGENDR = Union{Float64, Missing}[1, 1, 2, missing],
        )
        cb = NHANES._build_codebook_from_data(df, :RIAGENDR, categorical["RIAGENDR"])

        @test cb.code == ["1", "2", "."]
        @test cb.label == ["Male", "Female", "Missing"]
        @test cb.count == [2, 1, 1]
        @test eltype(cb.code) == String
        @test eltype(cb.count) == Int
    end

    @testset "continuous reports the published range" begin
        df = DataFrames.DataFrame(
            BMXWT = Union{Float64, Missing}[70.5, 82.1, 99.9, missing],
        )
        cb = NHANES._build_codebook_from_data(df, :BMXWT, continuous["BMXWT"])

        # One row per published row, not one row per observed weight
        @test cb.code == ["3.2 to 242.6", "."]
        @test cb.label == ["Range of Values", "Missing"]
        @test cb.count == [3, 1]
    end

    @testset "special codes counted apart from the range" begin
        df = DataFrames.DataFrame(
            RIDAGEYR = Union{Float64, Missing}[3, 40, 80, 80, missing],
        )
        cb = NHANES._build_codebook_from_data(df, :RIDAGEYR, mixed["RIDAGEYR"])

        @test cb.code == ["0 to 79", "80", "."]
        @test cb.count == [2, 2, 1]
    end

    @testset "codes absent from the codebook" begin
        df = DataFrames.DataFrame(RIAGENDR = Union{Float64, Missing}[1, 3])
        cb = NHANES._build_codebook_from_data(df, :RIAGENDR, categorical["RIAGENDR"])

        @test cb.code == ["1", "2", ".", "3"]
        @test cb.label == ["Male", "Female", "Missing", ""]
        @test cb.count == [1, 0, 0, 1]
    end

    @testset "string valued column" begin
        character =
            NHANES._parse_all_value_labels(
            CodebookFixtures.read_fixture("codebook_character.html"),
        )
        df = DataFrames.DataFrame(
            SLQ300 = Union{String, Missing}["22:30", "23:00", "77777", "", missing],
        )
        cb = NHANES._build_codebook_from_data(df, :SLQ300, character["SLQ300"])

        @test cb.code == [
            "Usual sleep time on weekdays or workdays",
            "77777",
            "99999",
            "< blank >",
        ]
        # A blank string is an absent value, like missing in a numeric column
        @test cb.count == [2, 1, 0, 2]
    end
end

@testitem "Codebook cache round trip" tags = [:unit] setup = [CodebookFixtures] begin
    import NHANES

    mktempdir() do root
        NHANES.with_cache_dir(root) do
            CodebookFixtures.prime_value_tables("DEMO_T", "codebook_categorical.html")

            loaded = NHANES._get_table_labels("DEMO_T")
            @test loaded["RIAGENDR"]["continuous"] == false
            @test loaded["RIAGENDR"]["labels"]["1"] == "Male"
            @test loaded["RIAGENDR"]["rows"][1]["code"] == "1"
        end
    end
end
