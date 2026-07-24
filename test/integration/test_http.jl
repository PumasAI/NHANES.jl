@testitem "HTTP integration" tags = [:integration] begin
    import NHANES

    @testset "fetch_html from CDC" begin
        html = NHANES.fetch_html(NHANES.codebook_url("DEMO_J"))
        @test !isempty(html)
        @test occursin("DEMO", html)
    end
end
