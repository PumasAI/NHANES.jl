@testitem "HTTP status extraction" tags = [:unit] begin
    import NHANES
    Downloads = NHANES.Downloads

    request_error(status; code = 0) = Downloads.RequestError(
        "https://example.com/x",
        code,
        "boom",
        Downloads.Response("https", "https://example.com/x", status, "", []),
    )

    @testset "http_status" begin
        @test NHANES.http_status(request_error(404)) == 404
        @test NHANES.http_status(request_error(503)) == 503

        # Transport-level failures carry no HTTP status
        @test NHANES.http_status(request_error(0; code = 6)) === nothing
        @test NHANES.http_status(ErrorException("nope")) === nothing
    end

    @testset "is_transient" begin
        # Connection and timeout failures are worth retrying
        @test NHANES.is_transient(request_error(0; code = 6))
        @test NHANES.is_transient(request_error(0; code = 28))

        # Server-side and rate-limit failures are worth retrying
        @test NHANES.is_transient(request_error(429))
        @test NHANES.is_transient(request_error(500))
        @test NHANES.is_transient(request_error(503))

        # Client errors will not change on a retry
        @test !NHANES.is_transient(request_error(400))
        @test !NHANES.is_transient(request_error(403))
        @test !NHANES.is_transient(request_error(404))

        @test !NHANES.is_transient(ErrorException("nope"))
    end
end

@testitem "Retry policy" tags = [:unit] begin
    import NHANES
    Downloads = NHANES.Downloads

    url = "https://example.com/DEMO_J.xpt"
    request_error(status) = Downloads.RequestError(
        url,
        0,
        "boom",
        Downloads.Response("https", url, status, "", []),
    )

    @testset "permanent failures are attempted once" begin
        attempts = Ref(0)
        @test_throws NHANES.DownloadError NHANES.with_retries(
            url,
            "download",
            3;
            backoff = 0.0,
        ) do
            attempts[] += 1
            throw(request_error(404))
        end
        @test attempts[] == 1
    end

    @testset "transient failures exhaust the retry budget" begin
        attempts = Ref(0)
        @test_throws NHANES.DownloadError NHANES.with_retries(
            url,
            "download",
            3;
            backoff = 0.0,
        ) do
            attempts[] += 1
            throw(request_error(503))
        end
        @test attempts[] == 3
    end

    @testset "a transient failure can be followed by success" begin
        attempts = Ref(0)
        result = NHANES.with_retries(url, "download", 3; backoff = 0.0) do
            attempts[] += 1
            attempts[] == 1 && throw(request_error(500))
            return "ok"
        end
        @test result == "ok"
        @test attempts[] == 2
    end

    @testset "DownloadError carries the HTTP status" begin
        err = try
            NHANES.with_retries(url, "download", 1; backoff = 0.0) do
                throw(request_error(404))
            end
        catch e
            e
        end
        @test err isa NHANES.DownloadError
        @test err.url == url
        @test err.status == 404
        @test occursin("download", err.message)

        # Transport-level failures leave the status empty
        err = try
            NHANES.with_retries(url, "download", 1; backoff = 0.0) do
                throw(
                    Downloads.RequestError(
                        url,
                        6,
                        "could not resolve host",
                        Downloads.Response("https", url, 0, "", []),
                    ),
                )
            end
        catch e
            e
        end
        @test err.status === nothing
        @test occursin("could not resolve host", err.message)
    end
end

@testitem "fetch_file" tags = [:unit] begin
    import NHANES

    source = tempname()
    write(source, "SAS transport file contents")

    @testset "downloads to the destination" begin
        mktempdir() do dir
            dest = joinpath(dir, "DEMO_J.xpt")
            @test NHANES.fetch_file("file://$source", dest) == dest
            @test read(dest, String) == "SAS transport file contents"

            # No temporary files left behind
            @test readdir(dir) == ["DEMO_J.xpt"]
        end
    end

    @testset "creates missing directories" begin
        mktempdir() do dir
            dest = joinpath(dir, "nested", "DEMO_J.xpt")
            NHANES.fetch_file("file://$source", dest)
            @test isfile(dest)
        end
    end

    @testset "a failed download leaves nothing behind" begin
        mktempdir() do dir
            dest = joinpath(dir, "DEMO_J.xpt")
            @test_throws NHANES.DownloadError NHANES.fetch_file(
                "file://$(tempname())",
                dest;
                retries = 1,
            )
            @test !isfile(dest)
            @test isempty(readdir(dir))
        end
    end

    @testset "a failed refresh keeps the cached file" begin
        mktempdir() do dir
            dest = joinpath(dir, "DEMO_J.xpt")
            write(dest, "cached contents")
            @test_throws NHANES.DownloadError NHANES.fetch_file(
                "file://$(tempname())",
                dest;
                retries = 1,
            )
            @test read(dest, String) == "cached contents"
            @test readdir(dir) == ["DEMO_J.xpt"]
        end
    end

    rm(source)
end

@testitem "fetch_html" tags = [:unit] begin
    import NHANES

    source = tempname()
    write(source, "<html><body>DEMO_J</body></html>")

    @testset "returns the body" begin
        @test NHANES.fetch_html("file://$source") ==
            "<html><body>DEMO_J</body></html>"
    end

    @testset "failures throw DownloadError" begin
        @test_throws NHANES.DownloadError NHANES.fetch_html(
            "file://$(tempname())";
            retries = 1,
        )
    end

    rm(source)
end
