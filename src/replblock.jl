"""
    struct REPLResult
"""
struct REPLResult1 end

"""
    CodeEvaluation.repl!(sandbox::Sandbox, code::AbstractString) -> AbstractValue

Evaluates the code in a special REPL-mode, where `code` gets split up into expressions,
each of which gets evaluated one by one. The output is a string representing what this
would look like if each expression had been evaluated in the REPL as separate commands.
"""
function repl!(sandbox::Sandbox, code::AbstractString)

end
