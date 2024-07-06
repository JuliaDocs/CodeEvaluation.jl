@testset "basic" begin
    let exprs = CodeEvaluation.parseblock("")
        @test isa(exprs, Vector{CodeEvaluation.ParsedExpression})
        @test isempty(exprs)
    end
    let exprs = CodeEvaluation.parseblock("0")
        @test isa(exprs, Vector{CodeEvaluation.ParsedExpression})
        @test length(exprs) == 1
        let expr = exprs[1]
            @test expr.expr == 0
            @test expr.code == "0\n" # TODO: trailing newline?
        end
    end
    let exprs = CodeEvaluation.parseblock("40  + 2")
        @test isa(exprs, Vector{CodeEvaluation.ParsedExpression})
        @test length(exprs) == 1
        let expr = exprs[1]
            @test expr.expr == :(40 + 2)
            @test expr.code == "40  + 2\n" # TODO: trailing newline?
        end
    end
end

@testset "complex" begin
    exprs = CodeEvaluation.parseblock(
        """
        x += 3
        γγγ_γγγ
        γγγ
        """
    )
    @test isa(exprs, Vector{CodeEvaluation.ParsedExpression})
    @test length(exprs) == 3

    let expr = exprs[1]
        @test expr.expr isa Expr
        @test expr.expr.head === :(+=)
        @test expr.code == "x += 3\n"
    end

    let expr = exprs[2]
        @test expr.expr === :γγγ_γγγ
        @test expr.code == "γγγ_γγγ\n"
    end

    let expr = exprs[3]
        @test expr.expr === :γγγ
        if VERSION >= v"1.10.0-DEV.1520" # JuliaSyntax merge
            @test expr.code == "γγγ\n\n"
        else
            @test expr.code == "γγγ\n"
        end
    end
end

# These tests were covering cases reported in
# https://github.com/JuliaDocs/Documenter.jl/issues/749
# https://github.com/JuliaDocs/Documenter.jl/issues/790
# https://github.com/JuliaDocs/Documenter.jl/issues/823
@testset "line endings" begin
    parse(s) = CodeEvaluation.parseblock(s)
    for LE in ("\r\n", "\n")
        l1, l2 = parse("x = Int[]$(LE)$(LE)push!(x, 1)$(LE)")
        @test l1.expr == :(x = Int[])
        @test l2.expr == :(push!(x, 1))
        if VERSION >= v"1.10.0-DEV.1520" # JuliaSyntax merge
            @test l1.code == "x = Int[]$(LE)$(LE)"
            @test l2.code == "push!(x, 1)$(LE)\n"
        else
            @test l1.code == "x = Int[]$(LE)"
            @test l2.code == "push!(x, 1)$(LE)"
        end
    end
end

@testset "multi-expr" begin
    let exprs = CodeEvaluation.parseblock("x; y; z")
        @test length(exprs) == 1
        @test exprs[1].expr == Expr(:toplevel, :x, :y, :z)
        @test exprs[1].code == "x; y; z\n"
    end

    let exprs = CodeEvaluation.parseblock("x; y; z\nq\n\n")
        @test length(exprs) == 2
        @test exprs[1].expr == Expr(:toplevel, :x, :y, :z)
        @test exprs[1].code == "x; y; z\n"
        @test exprs[2].expr == :q
        # TODO: There is a parsing difference here.. probably due to the JuliaSyntax change.
        if VERSION < v"1.10"
            @test exprs[2].code == "q\n"
        else
            @test exprs[2].code == "q\n\n\n"
        end
    end
end
