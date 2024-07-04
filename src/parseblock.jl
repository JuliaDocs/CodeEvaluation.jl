struct ParsedExpression
    expr::Any
    code::SubString{String}
end

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
and starting line number of the block.
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
    results = ParsedExpression[]
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
            push!(results, ParsedExpression(ex, str))
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
                _update_linenumbernodes!(expr, newfile, lineshift)
            else
                _update_linenumbernodes!(expr, linenumbernode.file, linenumbernode.line)
            end
            results[i] = ParsedExpression(expr, results[i][2])
        end
    end
    results
end

function _update_linenumbernodes!(x::Expr, newfile, lineshift)
    for i = 1:length(x.args)
        x.args[i] = _update_linenumbernodes!(x.args[i], newfile, lineshift)
    end
    return x
end
_update_linenumbernodes!(x::Any, newfile, lineshift) = x
function _update_linenumbernodes!(x::LineNumberNode, newfile, lineshift)
    return LineNumberNode(x.line + lineshift, newfile)
end
