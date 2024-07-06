@testset "Sandbox" begin
    sb = CodeEvaluation.Sandbox(:foo)
    @test isa(sb, CodeEvaluation.Sandbox)
    @test nameof(sb) == :foo
    @test sb.pwd == pwd()

    sb = CodeEvaluation.Sandbox(; workingdirectory=@__DIR__)
    @test isa(sb, CodeEvaluation.Sandbox)
    @test nameof(sb) isa Symbol
    @test sb.pwd == @__DIR__
end

@testset "Core.eval" begin
    sb = CodeEvaluation.Sandbox()
    @test Core.eval(sb, :(x = 2 + 2)) == 4
    @test Core.eval(sb, :x) == 4
    @test_throws UndefVarError Core.eval(sb, :y)
end

@testset "evaluate! - basic" begin
    sb = CodeEvaluation.Sandbox()

    r = CodeEvaluation.evaluate!(sb, :(2 + 2))
    @test !r.error
    @test r.value === 4
    @test r.output === ""

    r = CodeEvaluation.evaluate!(sb, :x)
    @test r.error
    @test r.value isa UndefVarError
    @test r.output === ""

    r = CodeEvaluation.evaluate!(sb, :(x = 2; nothing))
    @test !r.error
    @test r.value === nothing
    @test r.output === ""

    r = CodeEvaluation.evaluate!(sb, :x)
    @test !r.error
    @test r.value === 2
    @test r.output === ""
end

@testset "evaluate! - ans" begin
    # Setting the 'ans' variable is opt-in, so by default
    # it does not get set.
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.evaluate!(sb, :(2 + 2))
        @test !r.error
        @test r.value === 4
        @test r.output === ""
        r = CodeEvaluation.evaluate!(sb, :ans)
        @test r.error
        @test r.value isa UndefVarError
        @test r.output === ""
    end
    # If we set the 'setans' flag to true, then it does.
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.evaluate!(sb, :(2 + 2); setans=true)
        @test !r.error
        @test r.value === 4
        @test r.output === ""
        r = CodeEvaluation.evaluate!(sb, :ans)
        @test !r.error
        @test r.value === 4
        @test r.output === ""
        # Not setting it again, so it stays '4'
        r = CodeEvaluation.evaluate!(sb, :(3 * 3); setans=false)
        @test !r.error
        @test r.value === 9
        @test r.output === ""
        r = CodeEvaluation.evaluate!(sb, :ans)
        @test !r.error
        @test r.value === 4
        @test r.output === ""
    end
end

@testset "evaluate! - pwd" begin
    mktempdir() do path
        # By default, the sandbox picks up the current working directory when the sandbox
        # gets constructed.
        let sb = CodeEvaluation.Sandbox()
            r = CodeEvaluation.evaluate!(sb, :(pwd()))
            @test !r.error
            @test r.value != path
            @test r.value == pwd()
            @test r.output === ""
        end
        # But we can override that
        let sb = CodeEvaluation.Sandbox(; workingdirectory=path)
            r = CodeEvaluation.evaluate!(sb, :(pwd()))
            @test !r.error
            # Apparently on MacOS, pwd() and the temporary directory do
            # not exactly match. Put their realpath() versions do.
            @test realpath(r.value) == realpath(path)
            @test r.output === ""
        end
    end
end

@testset "evaluate! - output capture" begin
    sb = CodeEvaluation.Sandbox()

    r = CodeEvaluation.evaluate!(sb, :(print("123")))
    @test !r.error
    @test r.value === nothing
    @test r.output === "123"

    # stdout and stderr gets concatenated
    r = CodeEvaluation.evaluate!(sb, quote
        println(stdout, "123")
        println(stderr, "456")
    end)
    @test !r.error
    @test r.value === nothing
    @test r.output === "123\n456\n"

    # We can also capture the output in color
    r = CodeEvaluation.evaluate!(sb, quote
        printstyled("123"; color=:red)
    end)
    @test !r.error
    @test r.value === nothing
    @test r.output === "\e[31m123\e[39m"
    # But this can be disabled with color=false
    r = CodeEvaluation.evaluate!(sb, quote
        printstyled("123"; color=:red)
    end; color=false)
    @test !r.error
    @test r.value === nothing
    @test r.output === "123"

    # Capturing output logging macros
    r = CodeEvaluation.evaluate!(sb, quote
        @info "12345"
        42
    end; color=false)
    @test !r.error
    @test r.value === 42
    @test r.output == "[ Info: 12345\n"
end

@testset "evaluate! - scoping" begin
    expr = quote
        s = 0
        for i = 1:10
            s = i
        end
        s
    end

    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.evaluate!(sb, expr; color=false)
        @test !r.error
        @test r.value === 0
        # The evaluation prints a warning that should look something like this:
        #
        # ┌ Warning: Assignment to `s` in soft scope is ambiguous because a global variable by the same name exists: `s` will be treated as a new local. Disambiguate by using `local s` to suppress this warning or `global s` to assign to the existing global variable.
        # └ @ ~/.../CodeEvaluation/test/sandbox.jl:146
        @test contains(r.output, "┌ Warning:")
    end
    # However, if we set softscope=true, it follows the REPL soft scoping rules
    # https://docs.julialang.org/en/v1/manual/variables-and-scoping/#on-soft-scope
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.evaluate!(sb, expr; softscope=true, color=false)
        @test !r.error
        @test r.value === 10
        @test r.output == ""
    end
end
