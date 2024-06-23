# Constructs a new sandbox module, that emulates an empty Julia Main module.
function _sandbox_module(name::Symbol)
    # If the module does not exists already, we need to construct a new one.
    m = Module(name)
    # eval(expr) is available in the REPL (i.e. Main) so we emulate that for the sandbox
    Core.eval(m, :(eval(x) = Core.eval($m, x)))
    # modules created with Module() does not have include defined
    Core.eval(m, :(include(x) = Base.include($m, abspath(x))))
    return m
end

"""
    mutable struct Sandbox

Represents a fake Julia `Main` module, where code can be evaluated in isolation.

Technically, it wraps a fresh Julia `Module` object (accessible via the `.m` properties),
and the code is evaluated within the context of that module.

# Properties

- `m::Module`: The actual Julia module in which the code will be evaluated.
- `pwd::String`: The working directory where the code gets evaluated (irrespective of
  the current working directory of the process).

See also: [`evaluate!`](@ref).
"""
mutable struct Sandbox
    m::Module
    pwd::String
    _codebuffer::IOBuffer

    function Sandbox(
        name::Union{Symbol,Nothing}=nothing;
        workingdirectory::AbstractString=pwd()
    )
        if isnothing(name)
            name = Symbol("__CodeEvaluation__", _gensym_string())
        end
        return new(_sandbox_module(name), workingdirectory, IOBuffer(),)
    end
end

# TODO: by stripping the #-s, we're probably losing the uniqueness guarantee?
_gensym_string() = lstrip(string(gensym()), '#')

function evaluate!(sandbox::Sandbox; ansicolor::Bool=true)
    code = String(take!(sandbox._codebuffer))

    # Evaluate the code block. We redirect stdout/stderr to `buffer`.
    result, buffer = nothing, IOBuffer()

    # TODO: use keywords, linenumbernode?
    @show parseblock(code)
    for (ex, str) in parseblock(code)
        c = IOCapture.capture(rethrow=InterruptException, color=ansicolor) do
            cd(sandbox.pwd) do
                Core.eval(sandbox.m, ex)
            end
        end
        Core.eval(sandbox.m, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
        result = c.value
        print(buffer, c.output)
        if c.error
            #bt = Documenter.remove_common_backtrace(c.backtrace)
            bt = c.backtrace
            @error """
            Error executing code:
            ```
            $(code)
            ```
            """ exception = (c.value, bt)
            return
        end
    end

    return (; result, output=String(take!(buffer)))
end

Base.write(sandbox::Sandbox, data) = write(sandbox._codebuffer, data)

"""
Returns a vector of parsed expressions and their corresponding raw strings.

Returns a `Vector` of tuples `(expr, code)`, where `expr` is the corresponding expression
(e.g. a `Expr` or `Symbol` object) and `code` is the string of code the expression was
parsed from.

The keyword argument `skip = N` drops the leading `N` lines from the input string.

If `raise=false` is passed, the `Meta.parse` does not raise an exception on parse errors,
but instead returns an expression that will raise an error when evaluated. `parseblock`
returns this expression normally and it must be handled appropriately by the caller.

The `linenumbernode` can be passed as a `LineNumberNode` to give information about filename
and starting line number of the block (requires Julia 1.6 or higher).
"""
function parseblock(
    code::AbstractString;
    skip=0,
    keywords=true,
    raise=true,
    linenumbernode=nothing
)
    # Drop `skip` leading lines from the code block. Needed for deprecated `{docs}` syntax.
    code = string(code, '\n')
    code = last(split(code, '\n', limit=skip + 1))
    endofstr = lastindex(code)
    results = []
    cursor = 1
    while cursor < endofstr
        # Check for keywords first since they will throw parse errors if we `parse` them.
        line = match(r"^(.*)\r?\n"m, SubString(code, cursor)).match
        keyword = Symbol(strip(line))
        (ex, ncursor) = if keywords && haskey(Docs.keywords, keyword)
            (QuoteNode(keyword), cursor + lastindex(line))
        else
            try
                Meta.parse(code, cursor; raise=raise)
            catch err
                @error "parse error"
                break
            end
        end
        str = SubString(code, cursor, prevind(code, ncursor))
        if !isempty(strip(str)) && ex !== nothing
            push!(results, (ex, str))
        end
        cursor = ncursor
    end
    if linenumbernode isa LineNumberNode
        exs = Meta.parseall(code; filename=linenumbernode.file).args
        @assert length(exs) == 2 * length(results) "Issue at $linenumbernode:\n$code"
        for (i, ex) in enumerate(Iterators.partition(exs, 2))
            @assert ex[1] isa LineNumberNode
            expr = Expr(:toplevel, ex...) # LineNumberNode + expression
            # in the REPL each evaluation is considered a new file, e.g.
            # REPL[1], REPL[2], ..., so try to mimic that by incrementing
            # the counter for each sub-expression in this code block
            if linenumbernode.file === Symbol("REPL")
                newfile = "REPL[$i]"
                # to reset the line counter for each new "file"
                lineshift = 1 - ex[1].line
                update_linenumbernodes!(expr, newfile, lineshift)
            else
                update_linenumbernodes!(expr, linenumbernode.file, linenumbernode.line)
            end
            results[i] = (expr, results[i][2])
        end
    end
    results
end

function update_linenumbernodes!(x::Expr, newfile, lineshift)
    for i = 1:length(x.args)
        x.args[i] = update_linenumbernodes!(x.args[i], newfile, lineshift)
    end
    return x
end
update_linenumbernodes!(x::Any, newfile, lineshift) = x
function update_linenumbernodes!(x::LineNumberNode, newfile, lineshift)
    return LineNumberNode(x.line + lineshift, newfile)
end
