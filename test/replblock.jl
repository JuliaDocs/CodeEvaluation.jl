@testset "replblock! - basic" begin
    sb = CodeEvaluation.Sandbox()
    let r = CodeEvaluation.replblock!(sb, "nothing")
        @test r.sandbox === sb
        @test length(r.blocks) == 2
        let b = r.blocks[1]
            @test b.input
            @test b.code == "julia> nothing"
        end
        let b = r.blocks[2]
            @test !b.input
            @test b.code == ""
        end

        @test CodeEvaluation.join_to_string(r) == """
        julia> nothing

        """
    end
    let r = CodeEvaluation.replblock!(sb, "40 +  2")
        @test r.sandbox === sb
        @test length(r.blocks) == 2
        let b = r.blocks[1]
            @test b.input
            @test b.code == "julia> 40 +  2"
        end
        let b = r.blocks[2]
            @test !b.input
            @test b.code == "42\n"
        end
        @test CodeEvaluation.join_to_string(r) == """
        julia> 40 +  2
        42

        """
    end
    let r = CodeEvaluation.replblock!(sb, "println(\"...\")")
        @test r.sandbox === sb
        @test length(r.blocks) == 2
        let b = r.blocks[1]
            @test b.input
            @test b.code == "julia> println(\"...\")"
        end
        let b = r.blocks[2]
            @test !b.input
            @test b.code == "...\n"
        end
        @test CodeEvaluation.join_to_string(r) == """
        julia> println("...")
        ...

        """
    end
end

@testset "replblock! - multiple expressions" begin
    sb = CodeEvaluation.Sandbox()
    r = CodeEvaluation.replblock!(
        sb,
        """
x = 2
x += 2
x ^ 2
"""
    )
    @test length(r.blocks) == 6
    let b = r.blocks[1]
        @test b.input
        @test b.code == "julia> x = 2"
    end
    let b = r.blocks[2]
        @test !b.input
        @test b.code == "2\n"
    end
    let b = r.blocks[3]
        @test b.input
        @test b.code == "julia> x += 2"
    end
    let b = r.blocks[4]
        @test !b.input
        @test b.code == "4\n"
    end
    let b = r.blocks[5]
        @test b.input
        @test b.code == "julia> x ^ 2"
    end
    let b = r.blocks[6]
        @test !b.input
        @test b.code == "16\n"
    end

    @test CodeEvaluation.join_to_string(r) == """
    julia> x = 2
    2

    julia> x += 2
    4

    julia> x ^ 2
    16

    """
end

@testset "replblock! - output & results" begin
    sb = CodeEvaluation.Sandbox()
    r = CodeEvaluation.replblock!(
        sb,
        """
print(stdout, "out"); print(stderr, "err"); 42
"""
    )
    @test length(r.blocks) == 2
    let b = r.blocks[1]
        @test b.input
        @test b.code == "julia> print(stdout, \"out\"); print(stderr, \"err\"); 42"
    end
    let b = r.blocks[2]
        @test !b.input
        @test b.code == "outerr42\n"
    end
    @test CodeEvaluation.join_to_string(r) == """
    julia> print(stdout, "out"); print(stderr, "err"); 42
    outerr42

    """
end
