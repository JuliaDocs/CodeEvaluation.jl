"""
    CodeEvaluation.codeblock!(sandbox::Sandbox, code::AbstractString; kwargs...) -> Result

Evaluates a block of Julia code `code` in the `sandbox`, as if it is included as
a script. Returns a [`Result`](@ref) object, containing the result of the evaluation.

# Keywords

- `color::Bool=true`: determines whether or not to capture colored output (i.e. controls
  the IOContext).
"""
function codeblock!(sandbox::Sandbox, code::AbstractString; color::Bool=true)
    exprs = CodeEvaluation.parseblock(code)
    block_expr = Expr(:block, (expr.expr for expr in exprs)...)
    return evaluate!(sandbox, block_expr; setans=true, color)
end
