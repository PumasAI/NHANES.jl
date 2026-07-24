@testitem "Aqua quality assurance" tags = [:unit] begin
    import Aqua
    import NHANES

    Aqua.test_all(NHANES)
end
