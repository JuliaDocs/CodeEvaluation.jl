"""
    CodeEvaluation.codeblock!(sandbox::Sandbox, code::AbstractString) -> Result

...
"""
function codeblock!(sandbox::Sandbox, code::AbstractString; color::Bool=true)
    exprs = CodeEvaluation.parseblock(code)
    block_expr = Expr(:block, (expr.expr for expr in exprs)...)
    return evaluate!(sandbox, block_expr; setans=true, color)
end
