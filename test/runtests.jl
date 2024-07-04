using CodeEvaluation
using Test

@testset "CodeEvaluation.jl" begin
    @testset "parseblock()" begin
        include("parseblock.jl")
    end
    @testset "Sandbox" begin
        include("sandbox.jl")
    end
    @testset "codeblock!" begin
        include("codeblock.jl")
    end
end
