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

- `m :: Module`: The actual Julia module in which the code will be evaluated.
- `pwd :: String`: The working directory where the code gets evaluated (irrespective of
  the current working directory of the process).

# Constructors

```julia
Sandbox([name::Symbol]; workingdirectory::AbstractString=pwd())
```

Creates a new `Sandbox` object. If `name` is not provided, a unique name is generated.
`workingdirectory` can be used to set a working directory that is different from the current
one.

See also: [`evaluate!`](@ref).
"""
mutable struct Sandbox
    m::Module
    pwd::String

    function Sandbox(
        name::Union{Symbol,Nothing}=nothing;
        workingdirectory::AbstractString=pwd()
    )
        if isnothing(name)
            name = Symbol("__CodeEvaluation__", _gensym_string())
        end
        return new(_sandbox_module(name), workingdirectory)
    end
end
# TODO: by stripping the #-s, we're probably losing the uniqueness guarantee?
_gensym_string() = lstrip(string(gensym()), '#')

"""
    Core.eval(sandbox::Sandbox, expr) -> Any

Convenience function that evaluates the given Julia expression in the sandbox module.
This is low-level and does not do any handling of evalution (like enforcing the working
directory, capturing outputs, or error handling).
"""
function Base.Core.eval(sandbox::Sandbox, expr)
    return Core.eval(sandbox.m, expr)
end

"""
    Base.nameof(sandbox::Sandbox) -> Symbol

Returns the name of the underlying module of the `Sandbox` object.
"""
Base.nameof(sandbox::Sandbox) = nameof(sandbox.m)

# Will either be [`AnsValue`](@ref) if the code evaluated successfully,
# or [`ExceptionValue`](@ref) if it did not.
abstract type AbstractValue end

struct AnsValue <: AbstractValue
    object::Any
end
Base.getindex(v::AnsValue) = v.object

struct ExceptionValue <: AbstractValue
    exception::Any
    backtrace::Any
    full_backtrace::Any
end
Base.getindex(v::ExceptionValue) = v.exception

"""
    struct Result

Contains the result of an evaluation (see [`evaluate!`](@ref)).

# Properties

- `sandbox :: Sandbox`: The `Sandbox` object in which the code was evaluated.
- `value :: AbstractValue`: The result of the evaluation. Depending on the outcome
  of the evaluation (success vs error etc), this will be of a different subtype of
  [`AbstractValue`](@ref).
- `output :: String`: The captured stdout and stderr output of the evaluation.
"""
struct Result
    sandbox::Sandbox
    _value::AbstractValue
    output::String
    _source_expr::Any
end

function Base.getproperty(r::Result, name::Symbol)
    if name === :error
        return getfield(r, :_value) isa ExceptionValue
    elseif name === :value
        return getfield(r, :_value)[]
    elseif name === :backtrace
        value = getfield(r, :_value)
        if value isa ExceptionValue
            return value.backtrace
        else
            return nothing
        end
    else
        return getfield(r, name)
    end
end

function Base.propertynames(::Type{Result})
    return (:sandbox, :value, :output, :error)
end

"""
    CodeEvaluation.evaluate!(sandbox::Sandbox, expr; kwargs...) -> Result

Low-level function to evaluate Julia expressions in a sandbox. The keyword arguments can be
used to control how exactly the code is evaluated.

# Keyword arguments

- `setans :: Bool=false`: whether or not to set the result of the expression to `ans`, emulating
  the behavior of the Julia REPL.
- `softscope :: Bool=false`: evaluates the code in REPL softscope mode.
- `color :: Bool=true`: whether or not to capture colored output (i.e. controls the IOContext
  of the output stream; see the `IOCapture.capture` function for more details).

# REPL mode

When evaluating the code in "REPL mode" (`repl = true`), there are the following differences:

- The code is evaluated in a "soft scope" (i.e. `REPL.softscope` is applied to the code).
- It honors the semicolon suppression (i.e. the result of the last expression is set to `nothing`
  if the line ends with a semicolon).
"""
function evaluate!(
    sandbox::Sandbox,
    expr;
    color::Bool=true,
    softscope::Bool=false,
    setans::Bool=false
)
    if softscope
        expr = REPL.softscope(expr)
    end
    c = IOCapture.capture(; rethrow=InterruptException, color) do
        cd(sandbox.pwd) do
            Core.eval(sandbox, expr)
        end
    end
    value = if c.error
        ExceptionValue(c.value, c.backtrace, c.backtrace)
    else
        if setans
            Core.eval(sandbox.m, Expr(:global, Expr(:(=), :ans, QuoteNode(c.value))))
        end
        AnsValue(c.value)
    end
    return Result(
        sandbox,
        value,
        c.output,
        expr,
    )
end

function _remove_common_backtrace(bt, reference_bt = backtrace())
    cutoff = nothing
    # We'll start from the top of the backtrace (end of the array) and go down, checking
    # if the backtraces agree
    for ridx in 1:length(bt)
        # Cancel search if we run out the reference BT or find a non-matching one frames:
        if ridx > length(reference_bt) || bt[length(bt) - ridx + 1] != reference_bt[length(reference_bt) - ridx + 1]
            cutoff = length(bt) - ridx + 1
            break
        end
    end
    # It's possible that the loop does not find anything, i.e. that all BT elements are in
    # the reference_BT too. In that case we'll just return an empty BT.
    bt[1:(cutoff === nothing ? 0 : cutoff)]
end
