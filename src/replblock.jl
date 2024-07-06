"""
    struct CodeBlock

Represents a single block in a sequence of REPL inputs and outputs in the [`REPLResult`](@ref) object.

# Properties

- `input::Bool`: whether this block represents a REPL input (i.e. an input `julia>`) or an output
  from the REPL (either the plain string representation of the object, or the standard output or error
  stream contents).

- `code::String`: the contents of the block

"""
struct CodeBlock
    input::Bool
    code::String
end

"""
    struct REPLResult

The result from a [`replblock!`](@ref) evaluation. It contains a sequence of input and output blocks.
The inputs and outputs are separated, so that it would be easy for the users to style them differently
if that is needed.

See also: [`CodeBlock`](@ref), [`join_to_string`](@ref).

# Properties

- `sandbox :: Sandbox`: The `Sandbox` object in which the code was evaluated.
- `blocks :: Vector{CodeBlock}`: The sequence of input and output block text.
"""
struct REPLResult
    sandbox::Sandbox
    blocks::Vector{CodeBlock}
    _code::AbstractString
    _source_exprs::Vector{Any}
end

function join_to_string(result::REPLResult)
    out = IOBuffer()
    for block in result.blocks
        println(out, block.code)
    end
    return String(take!(out))
end

"""
    CodeEvaluation.replblock!(sandbox::Sandbox, code::AbstractString; kwargs...) -> REPLResult

Evaluates the code in a special REPL-mode, where `code` gets split up into expressions,
each of which gets evaluated one by one. The output is a string representing what this
would look like if each expression had been evaluated in the REPL as separate commands.

See also: [`REPLResult`](@ref), [`join_to_string`](@ref).

# Keywords

- `color::Bool=true`: determines whether or not to capture colored output (i.e. controls
  the IOContext).

- `post_process_inputs`: a function that can be used to post-process the input expressions.
  It does not affect the code that is evaluated, just what gets included in the REPL input
  blocks.
"""
function replblock!(
    sandbox::Sandbox, code::AbstractString;
    color::Bool=true,
    post_process_inputs = identity,
)
    exprs = parseblock(
        code;
        keywords = false,
        # line unused, set to 0
        linenumbernode = LineNumberNode(0, "REPL"),
    )
    codeblocks = CodeBlock[]
    source_exprs = map(exprs) do pex
        input = post_process_inputs(pex.code)
        result = evaluate!(sandbox, pex.expr; color, softscope=true, setans = true)
        # Add the input and output to the codeblocks, if appropriate.
        if !isempty(input)
            push!(codeblocks, CodeBlock(true, _prepend_prompt(input)))
        end
        # Determine the output string and add to codeblocks
        object_repl_repr = let buffer = IOContext(IOBuffer(), :color=>color)
            if !result.error
                hide = REPL.ends_with_semicolon(input)
                _result_to_string(buffer, hide ? nothing : result.value)
            else
                _error_to_string(buffer, result.value, result.backtrace)
            end
        end
        # Construct the full output. We have to prepend the stdout/-err to the
        # output first, and then finally render the returned object.
        out = IOBuffer()
        print(out, result.output) # stdout and stderr from the evaluation
        if !isempty(input) && !isempty(object_repl_repr)
            print(out, object_repl_repr, "\n")
        end
        outstr = _remove_sandbox_from_output(sandbox, String(take!(out)))
        push!(codeblocks, CodeBlock(false, outstr))
        return (;
            expr = pex,
            result,
            input,
            outstr,
        )
    end
    return REPLResult(sandbox, codeblocks, code, source_exprs)
end

# Replace references to gensym'd module with Main
function _remove_sandbox_from_output(sandbox::Sandbox, str::AbstractString)
    replace(str, Regex(("(Main\\.)?$(nameof(sandbox))")) => "Main")
end

function _prepend_prompt(input::AbstractString)
    prompt  = "julia> "
    padding = " "^length(prompt)
    out = IOBuffer()
    for (n, line) in enumerate(split(input, '\n'))
        line = rstrip(line)
        println(out, n == 1 ? prompt : padding, line)
    end
    rstrip(String(take!(out)))
end

function _result_to_string(buffer::IO, value::Any)
    if value !== nothing
        Base.invokelatest(
            show,
            IOContext(buffer, :limit => true),
            MIME"text/plain"(),
            value
        )
    end
    return _sanitise(buffer)
end

function _error_to_string(buffer::IO, e::Any, bt)
    # Remove unimportant backtrace info.
    bt = _remove_common_backtrace(bt, backtrace())
    # Remove everything below the last eval call (which should be the one in IOCapture.capture)
    index = findlast(ptr -> Base.ip_matches_func(ptr, :eval), bt)
    bt = (index === nothing) ? bt : bt[1:(index - 1)]
    # Print a REPL-like error message.
    print(buffer, "ERROR: ")
    Base.invokelatest(showerror, buffer, e, bt)
    return _sanitise(buffer)
end

# Strip trailing whitespace from each line and return resulting string
function _sanitise(buffer::IO)
    out = IOBuffer()
    for line in eachline(seekstart(Base.unwrapcontext(buffer)[1]))
        println(out, rstrip(line))
    end
    return rstrip(String(take!(out)), '\n')
end
