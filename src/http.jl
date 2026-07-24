import Downloads

"""Base delay in seconds before a retry, doubled on each further attempt."""
const RETRY_BACKOFF_SECONDS = 1.0

"""
    http_status(e) -> Union{Int,Nothing}

Get the HTTP status carried by a failure, or `nothing` when the request failed
before a response arrived.
"""
function http_status(e)
    e isa Downloads.RequestError || return nothing
    status = e.response.status
    return status > 0 ? Int(status) : nothing
end

"""
    is_transient(e) -> Bool

Report whether a failure is worth retrying: connection and timeout failures,
HTTP 429, and HTTP 5xx. A 4xx response means the resource will not appear on a
second attempt.
"""
function is_transient(e)
    status = http_status(e)
    status === nothing && return e isa Downloads.RequestError
    return status == 429 || status >= 500
end

"""
    with_retries(f, url, action, retries; backoff = RETRY_BACKOFF_SECONDS)

Run `f`, retrying transient failures with exponential backoff.

# Arguments
- `f`: Zero-argument function performing the request
- `url::AbstractString`: URL being requested, reported in errors
- `action::AbstractString`: What `f` is doing, reported in errors
- `retries::Int`: Maximum number of attempts
- `backoff::Real`: Delay in seconds before the first retry

# Throws
- `DownloadError`: If the request fails permanently or runs out of attempts
"""
function with_retries(
        f,
        url::AbstractString,
        action::AbstractString,
        retries::Int;
        backoff::Real = RETRY_BACKOFF_SECONDS,
    )
    for attempt in 1:retries
        try
            return f()
        catch e
            e isa InterruptException && rethrow()
            if attempt == retries || !is_transient(e)
                tries = attempt == 1 ? "1 attempt" : "$attempt attempts"
                throw(
                    DownloadError(
                        url,
                        "Failed to $action after $tries: " *
                            sprint(showerror, e),
                        http_status(e),
                    ),
                )
            end
            sleep(backoff * 2.0^(attempt - 1))
        end
    end
    return
end

"""
    fetch_file(url::AbstractString, dest::AbstractString; retries::Int=3) -> String

Download a file from a URL to a destination path.

The transfer goes to a temporary file next to `dest` and is renamed into place
once complete, so a failed download never leaves a truncated file at `dest`.

# Arguments
- `url::AbstractString`: URL to download from
- `dest::AbstractString`: Local path to save the file
- `retries::Int=3`: Maximum number of attempts

# Throws
- `DownloadError`: If the download fails
"""
function fetch_file(url::AbstractString, dest::AbstractString; retries::Int = 3)
    dir = dirname(abspath(dest))
    mkpath(dir)

    return with_retries(url, "download", retries) do
        temp = tempname(dir; cleanup = false)
        try
            Downloads.download(url, temp)
            mv(temp, dest; force = true)
        catch
            rm(temp; force = true)
            rethrow()
        end
        return dest
    end
end

"""
    fetch_html(url::AbstractString; retries::Int=3) -> String

Fetch HTML content from a URL.

# Arguments
- `url::AbstractString`: URL to fetch
- `retries::Int=3`: Maximum number of attempts

# Throws
- `DownloadError`: If the fetch fails
"""
function fetch_html(url::AbstractString; retries::Int = 3)
    return with_retries(url, "fetch HTML", retries) do
        body = IOBuffer()
        Downloads.download(url, body)
        return String(take!(body))
    end
end
