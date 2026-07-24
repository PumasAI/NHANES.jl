@testitem "URL construction" tags = [:unit] begin
    import NHANES

    @testset "BASE_URL" begin
        @test NHANES.BASE_URL == "https://wwwn.cdc.gov"
    end

    @testset "cycle_suffix" begin
        # 1999-2000 has no suffix (first continuous NHANES cycle)
        @test NHANES.cycle_suffix(1999) == ""

        # Letter suffixes start at B for 2001-2002
        @test NHANES.cycle_suffix(2001) == "_B"
        @test NHANES.cycle_suffix(2003) == "_C"
        @test NHANES.cycle_suffix(2005) == "_D"
        @test NHANES.cycle_suffix(2007) == "_E"
        @test NHANES.cycle_suffix(2009) == "_F"
        @test NHANES.cycle_suffix(2011) == "_G"
        @test NHANES.cycle_suffix(2013) == "_H"
        @test NHANES.cycle_suffix(2015) == "_I"
        @test NHANES.cycle_suffix(2017) == "_J"
        @test NHANES.cycle_suffix(2021) == "_L"

        @test_throws ArgumentError NHANES.cycle_suffix(1998)
        @test_throws ArgumentError NHANES.cycle_suffix(2000)  # Even years not valid
        @test_throws ArgumentError NHANES.cycle_suffix(2002)
    end

    @testset "cycle_suffix 2019" begin
        # CDC never published 2019-2020; the data went into the P_ tables
        @test_throws ArgumentError NHANES.cycle_suffix(2019)
        @test_throws "never released" NHANES.cycle_suffix(2019)
        @test_throws "2019-2020" NHANES.cycle_suffix(2019)
        @test_throws ":P" NHANES.cycle_suffix(2019)
    end

    @testset "suffix_to_year" begin
        @test NHANES.suffix_to_year("") == 1999
        @test NHANES.suffix_to_year("_B") == 2001
        @test NHANES.suffix_to_year("_C") == 2003
        @test NHANES.suffix_to_year("_J") == 2017
        @test NHANES.suffix_to_year("_L") == 2021

        @test NHANES.suffix_to_year("B") == 2001
        @test NHANES.suffix_to_year("J") == 2017

        @test_throws ArgumentError NHANES.suffix_to_year("_Z")
        @test_throws ArgumentError NHANES.suffix_to_year("_K")
    end

    @testset "parse_table_name" begin
        base, suffix = NHANES.parse_table_name("DEMO_J")
        @test base == "DEMO"
        @test suffix == "_J"

        base, suffix = NHANES.parse_table_name("ALB_CR_J")
        @test base == "ALB_CR"
        @test suffix == "_J"

        # 1999-2000 tables (no letter suffix)
        base, suffix = NHANES.parse_table_name("DEMO")
        @test base == "DEMO"
        @test suffix == ""

        base, suffix = NHANES.parse_table_name("ALB_CR")
        @test base == "ALB_CR"
        @test suffix == ""

        # Pre-pandemic tables use a prefix instead of a suffix
        base, suffix = NHANES.parse_table_name("P_BMX")
        @test base == "BMX"
        @test suffix == "P_"

        base, suffix = NHANES.parse_table_name("P_ALB_CR")
        @test base == "ALB_CR"
        @test suffix == "P_"
    end

    @testset "table_url" begin
        url = NHANES.table_url("DEMO_J")
        @test url ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/DEMO_J.xpt"

        url = NHANES.table_url("DEMO")
        @test url ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/1999/DataFiles/DEMO.xpt"

        url = NHANES.table_url("ALB_CR_J")
        @test url ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/ALB_CR_J.xpt"

        # Pre-pandemic tables live in the 2017 folder
        url = NHANES.table_url("P_BMX")
        @test url ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_BMX.xpt"
    end

    @testset "variablelist_url" begin
        url = NHANES.variablelist_url(:Demographics, 2017)
        @test occursin("Component=Demographics", url)
        @test occursin("CycleBeginYear=2017", url)
        @test startswith(url, "https://wwwn.cdc.gov")

        url = NHANES.variablelist_url(:Laboratory, 2015)
        @test occursin("Component=Laboratory", url)
        @test occursin("CycleBeginYear=2015", url)

        # Pre-pandemic cycle uses a cycle range instead of a begin year
        url = NHANES.variablelist_url(:Demographics, :P)
        @test occursin("Component=Demographics", url)
        @test occursin("Cycle=2017-2020", url)
        @test !occursin("CycleBeginYear", url)

        @test_throws ArgumentError NHANES.variablelist_url(:Bloodwork, 2017)
    end

    @testset "codebook_url" begin
        url = NHANES.codebook_url("DEMO_J")
        @test occursin("DEMO_J", url)
        @test endswith(url, ".htm")
        @test startswith(url, "https://wwwn.cdc.gov")

        url = NHANES.codebook_url("P_BMX")
        @test url ==
            "https://wwwn.cdc.gov/Nchs/Data/Nhanes/Public/2017/DataFiles/P_BMX.htm"
    end

    @testset "table name validation" begin
        # Names that could escape the DataFiles directory are rejected
        for bad in ["../../etc/passwd", "DEMO/../X", "DEMO J", "", "DEMO;rm"]
            @test_throws ArgumentError NHANES.table_url(bad)
            @test_throws ArgumentError NHANES.codebook_url(bad)
        end
    end
end

@testitem "resolve_url" tags = [:unit] begin
    import NHANES

    base = "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/datafiles.aspx"

    @testset "absolute URL passes through" begin
        @test NHANES.resolve_url(base, "http://example.com/a.xpt") ==
            "http://example.com/a.xpt"
    end

    @testset "protocol-relative URL takes the base scheme" begin
        @test NHANES.resolve_url(base, "//example.com/a.xpt") ==
            "https://example.com/a.xpt"
    end

    @testset "root-relative path replaces the base path" begin
        @test NHANES.resolve_url(base, "/nchs/data/a.xpt") ==
            "https://wwwn.cdc.gov/nchs/data/a.xpt"
    end

    @testset "bare relative path resolves against the base directory" begin
        @test NHANES.resolve_url(base, "data/foo.xpt") ==
            "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/data/foo.xpt"
    end

    @testset "dot segment resolves against the base directory" begin
        @test NHANES.resolve_url(base, "./foo.xpt") ==
            "https://wwwn.cdc.gov/nchs/nhanes/nhanes3/foo.xpt"
    end

    @testset "parent segments climb the base directory" begin
        @test NHANES.resolve_url(base, "../foo.xpt") ==
            "https://wwwn.cdc.gov/nchs/nhanes/foo.xpt"
        @test NHANES.resolve_url(base, "../../data/nhanes3/1a/adult.dat") ==
            "https://wwwn.cdc.gov/nchs/data/nhanes3/1a/adult.dat"
    end

    @testset "parent segments stop at the root" begin
        @test NHANES.resolve_url(base, "../../../../../foo.xpt") ==
            "https://wwwn.cdc.gov/foo.xpt"
    end

    @testset "query and fragment survive resolution" begin
        @test NHANES.resolve_url(base, "../search/datapage.aspx?Cycle=1959-1994") ==
            "https://wwwn.cdc.gov/nchs/nhanes/search/datapage.aspx?Cycle=1959-1994"
        @test NHANES.resolve_url(base, "#core") == base * "#core"
    end

    @testset "base without a path" begin
        @test NHANES.resolve_url("https://wwwn.cdc.gov", "a.xpt") ==
            "https://wwwn.cdc.gov/a.xpt"
    end
end
