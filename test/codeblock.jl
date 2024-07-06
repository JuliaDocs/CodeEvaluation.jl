@testset "codeblock! - basic" begin
    # Basic cases
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, "2+2")
        @test !r.error
        @test r.value == 4
        @test r.output == ""
    end
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, ":foo")
        @test !r.error
        @test r.value === :foo
        @test r.output == ""
    end
    # Output capture
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, "print(\"123\")")
        @test !r.error
        @test r.value === nothing
        @test r.output == "123"
    end
    # Multi-line evaluation
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, "x=25\nx *= 2\nx - 8")
        @test !r.error
        @test r.value == 42
        @test r.output == ""
    end
    # Complex session
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, "x=25\nx *= 2\ny = x - 8")
        @test !r.error
        @test r.value == 42
        @test r.output == ""

        r = CodeEvaluation.codeblock!(sb, "print(string(y))")
        @test !r.error
        @test r.value === nothing
        @test r.output == "42"

        r = CodeEvaluation.codeblock!(sb, "s = string(y); println(s); length(s)")
        @test !r.error
        @test r.value == 2
        @test r.output == "42\n"
    end
end

@testset "codeblock! - errors" begin
    # Error handling
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, "error(\"x\")")
        @test r.error
        @test r.value isa ErrorException
        @test r.value.msg == "x"
        @test r.output == ""
    end
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, "print(\"x\"); error(\"x\"); print(\"y\")")
        @test r.error
        @test r.value isa ErrorException
        @test r.value.msg == "x"
        @test r.output == "x"
    end
    let sb = CodeEvaluation.Sandbox()
        r = CodeEvaluation.codeblock!(sb, "print(\"x\")\nerror(\"x\")\nprint(\"y\")")
        @test r.error
        @test r.value isa ErrorException
        @test r.value.msg == "x"
        @test r.output == "x"
    end
end

@testset "codeblock! - working directory" begin
    # Working directory
    mktempdir() do path
        let sb = CodeEvaluation.Sandbox(; workingdirectory=path)
            let r = CodeEvaluation.codeblock!(sb, "pwd()")
                @test !r.error
                # Apparently on MacOS, the tempdir is a symlink ??
                @show r.value islink(r.value) isdir(r.value)
                @show path islink(path) isdir(path)
                @test r.value == path
                @test r.output == ""
            end

            write(joinpath(path, "test.txt"), "123")
            let r = CodeEvaluation.codeblock!(sb, """
                isfile("test.txt"), read("test.txt", String)
                """)
                @test !r.error
                @test r.value === (true, "123")
            end
            let r = CodeEvaluation.codeblock!(sb, """
                isfile("does-not-exist.txt")
                """)
                @test !r.error
                @test r.value === false
            end
            let r = CodeEvaluation.codeblock!(sb, """
                read("does-not-exist.txt", String)
                """)
                @test r.error
                @test r.value isa SystemError
            end
        end
    end
end

@testset "codeblock! - parse errors" begin
    sb = CodeEvaluation.Sandbox()
    let r = CodeEvaluation.codeblock!(sb, "...")
        @test_broken r.error
        @test_broken r.value isa ParseError
        @test r.output == ""
    end
end
