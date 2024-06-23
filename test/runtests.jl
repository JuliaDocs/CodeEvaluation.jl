using CodeEvaluation
using Test

@testset "CodeEvaluation.jl" begin
    @testset "_parseblock" begin
        code = """
        x += 3
        γγγ_γγγ
        γγγ
        """
        exprs = CodeEvaluation._parseblock(code)

        @test isa(exprs, Vector)
        @test length(exprs) === 3

        @test isa(exprs[1][1], Expr)
        @test exprs[1][1].head === :+=
        @test exprs[1][2] == "x += 3\n"

        @test exprs[2][2] == "γγγ_γγγ\n"

        @test exprs[3][1] === :γγγ
        if VERSION >= v"1.10.0-DEV.1520" # JuliaSyntax merge
            @test exprs[3][2] == "γγγ\n\n"
        else
            @test exprs[3][2] == "γγγ\n"
        end
    end

    # These tests were covering cases reported in
    # https://github.com/JuliaDocs/Documenter.jl/issues/749
    # https://github.com/JuliaDocs/Documenter.jl/issues/790
    # https://github.com/JuliaDocs/Documenter.jl/issues/823
    let parse(x) = CodeEvaluation._parseblock(x)
        for LE in ("\r\n", "\n")
            l1, l2 = parse("x = Int[]$(LE)$(LE)push!(x, 1)$(LE)")
            @test l1[1] == :(x = Int[])
            @test l2[1] == :(push!(x, 1))
            if VERSION >= v"1.10.0-DEV.1520" # JuliaSyntax merge
                @test l1[2] == "x = Int[]$(LE)$(LE)"
                @test l2[2] == "push!(x, 1)$(LE)\n"
            else
                @test l1[2] == "x = Int[]$(LE)"
                @test l2[2] == "push!(x, 1)$(LE)"
            end
        end
    end

    @testset "NamedSandboxes" begin
        sandboxes = CodeEvaluation.NamedSandboxes(@__DIR__, "testsandbox")
        sb1 = get!(sandboxes, "foo")
        sb2 = get!(sandboxes, "bar")
        sb3 = get!(sandboxes, "foo")
        @test sb1.m !== sb2.m
        @test sb1.m === sb3.m
        @test sb2.m !== sb3.m
    end

    @testset "evaluate!" begin
        let sb = CodeEvaluation.Sandbox(:foo; workingdirectory=@__DIR__)
            write(sb, "2 + 2")
            (result, output) = CodeEvaluation.evaluate!(sb)
            @test result === 4
            @test output === ""
        end

        let sb = CodeEvaluation.Sandbox(:foo; workingdirectory=@__DIR__)
            write(sb, "print(\"123\")")
            (result, output) = CodeEvaluation.evaluate!(sb)
            @test result === nothing
            @test output === "123"
        end

        let sb = CodeEvaluation.Sandbox(:foo; workingdirectory=@__DIR__)
            write(
                sb,
                """
                x = 2 + 2
                print(x)
                x + 1
                """
            )
            (result, output) = CodeEvaluation.evaluate!(sb)
            @test result === 5
            @test output === "4"
        end
    end
end
