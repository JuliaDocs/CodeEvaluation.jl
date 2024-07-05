module CodeEvaluation
using IOCapture: IOCapture
using REPL: REPL
#using Base64: stringmime

include("parseblock.jl")
include("sandbox.jl")
include("codeblock.jl")
include("replblock.jl")

end
