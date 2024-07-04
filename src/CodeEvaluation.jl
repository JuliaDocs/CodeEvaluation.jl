module CodeEvaluation
using IOCapture: IOCapture
using REPL: REPL

include("parseblock.jl")
include("sandbox.jl")
include("codeblock.jl")
include("replblock.jl")

end
