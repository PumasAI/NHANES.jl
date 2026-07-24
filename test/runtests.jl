using TestItemRunner

# Integration test items hit live CDC endpoints, so they are opt-in. Everything
# else runs by default, so an item that is missing a tag still runs.
const RUN_INTEGRATION = get(ENV, "NHANES_TEST_INTEGRATION", "false") == "true"

selected(tags) = RUN_INTEGRATION || !(:integration in tags)

@run_package_tests filter = ti -> selected(ti.tags)
