# Contributing to NHANES.jl

## Running the tests

The suite uses [TestItemRunner.jl](https://github.com/julia-vscode/TestItemRunner.jl).
By default only the offline `:unit` items run:

```julia
using Pkg
Pkg.test("NHANES")
```

Set `NHANES_TEST_INTEGRATION=true` to also run the `:integration` items:

```bash
NHANES_TEST_INTEGRATION=true julia --project -e 'using Pkg; Pkg.test("NHANES")'
```

CI runs both on every pull request. The unit items run across the version and
platform matrix; the integration items run once on ubuntu-latest, so a change
makes a single pass over the CDC endpoints rather than one per matrix entry.
They stay off in local development because they are slow and need network
access.

## Test item tags

Every `@testitem` declares exactly one tag:

- `tags = [:unit]` for items that run offline.
- `tags = [:integration]` for items that fetch from the CDC.

`test/runtests.jl` skips `:integration` items unless
`NHANES_TEST_INTEGRATION=true`. Everything else runs, so an item that is
missing its tag still executes rather than disappearing silently.

## Formatting

Run the formatter before pushing:

```bash
just format
```

CI runs the same recipe and then `git diff --exit-code`, so unformatted code
fails the `format` job.

## Network dependence

The package reads live endpoints under `https://wwwn.cdc.gov`. Integration
tests fail when the CDC site is down, rate limits, changes its HTML, or
republishes a data file. Since they gate pull requests, a red integration job
blocks a merge for reasons that may have nothing to do with the change. Check
the failure against the current state of the site before treating it as a
regression, and re-run the job before digging further.

## Examples

`examples/nhanesA_equivalents.jl` maps R `nhanesA` calls to their NHANES.jl
equivalents. Nothing executes it, in CI or elsewhere, so it drifts as the API
changes. Check it against the current API before relying on it, and update it
when you change a function it calls.
