@testitem "Cache infrastructure" tags = [:unit] begin
    import NHANES

    @testset "cache_dir default" begin
        dir = NHANES.cache_dir()
        @test isdir(dir)
        @test occursin("scratchspaces", dir)
    end

    mktempdir() do root
        NHANES.with_cache_dir(root) do
            @testset "cache_dir override" begin
                @test NHANES.cache_dir() == root
                @test isdir(root)
            end

            @testset "data_cache_path" begin
                path = NHANES.data_cache_path("DEMO_J")
                @test startswith(path, root)
                @test endswith(path, "DEMO_J.xpt")
                @test occursin("data", path)
            end

            @testset "metadata_cache_path" begin
                path = NHANES.metadata_cache_path("codebook", "DEMO_J")
                @test startswith(path, root)
                @test occursin("metadata", path)
                @test occursin("codebook", path)
                @test endswith(path, ".json")

                # Keys used across the package
                for (category, key) in [
                        ("codebook", "DEMO_J_valuetables"),
                        ("tables", "Demographics_2017"),
                        ("variablelist", "Demographics_P"),
                        ("variables", "P_BMX"),
                    ]
                    path = NHANES.metadata_cache_path(category, key)
                    @test startswith(path, root)
                    @test endswith(path, "$key.json")
                end
            end

            @testset "is_cached" begin
                @test !NHANES.is_cached("NONEXISTENT_TABLE_XYZ")

                path = NHANES.data_cache_path("TEST_CACHE")
                mkpath(dirname(path))
                write(path, "test")
                @test NHANES.is_cached("TEST_CACHE")
                rm(path)
            end

            @testset "METADATA_TTL_DAYS" begin
                @test NHANES.METADATA_TTL_DAYS > 0
                @test NHANES.METADATA_TTL_DAYS isa Integer
            end

            @testset "is_metadata_fresh" begin
                @test !NHANES.is_metadata_fresh("/nonexistent/path.json")

                path = NHANES.metadata_cache_path("test", "fresh_test")
                mkpath(dirname(path))
                write(path, "{}")
                @test NHANES.is_metadata_fresh(path)
                rm(path)
            end

            @testset "save_metadata and load_metadata" begin
                saved =
                    NHANES.save_metadata("test", "roundtrip", Dict("a" => 1))
                @test isfile(saved)
                @test NHANES.load_metadata("test", "roundtrip") ==
                    Dict("a" => 1)
                @test NHANES.load_metadata("test", "missing") === nothing
            end
        end
    end

    @testset "with_cache_dir restores the previous root" begin
        before = NHANES.CACHE_ROOT_OVERRIDE[]
        mktempdir() do root
            NHANES.with_cache_dir(root) do
                @test NHANES.CACHE_ROOT_OVERRIDE[] == root
            end
            @test NHANES.CACHE_ROOT_OVERRIDE[] === before

            @test_throws ErrorException NHANES.with_cache_dir(root) do
                error("boom")
            end
            @test NHANES.CACHE_ROOT_OVERRIDE[] === before
        end
    end
end

@testitem "Cache path validation" tags = [:unit] begin
    import NHANES

    mktempdir() do root
        NHANES.with_cache_dir(root) do
            @testset "data_cache_path rejects traversal" begin
                for bad in ["../../../../pwned", "a/b", "DEMO J", ""]
                    @test_throws ArgumentError NHANES.data_cache_path(bad)
                end
            end

            @testset "metadata_cache_path rejects traversal" begin
                @test_throws ArgumentError NHANES.metadata_cache_path(
                    "../../..",
                    "pwned",
                )
                @test_throws ArgumentError NHANES.metadata_cache_path(
                    "codebook",
                    "../../../../pwned",
                )
            end

            @testset "is_cached rejects traversal" begin
                @test_throws ArgumentError NHANES.is_cached("../../pwned")
            end
        end
    end
end

@testitem "Cache clear" tags = [:unit] begin
    import NHANES

    mktempdir() do root
        NHANES.with_cache_dir(root) do
            @testset "clear_cache" begin
                test_path = NHANES.data_cache_path("CLEAR_TEST")
                mkpath(dirname(test_path))
                write(test_path, "test data")
                @test isfile(test_path)

                NHANES.clear_cache()

                @test !isfile(test_path)
                @test isdir(NHANES.cache_dir())
            end
        end
    end
end
