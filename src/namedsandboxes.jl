struct NamedSandboxes
    _pwd::String
    _prefix::String
    _sandboxes::Dict{Symbol,Sandbox}

    function NamedSandboxes(pwd::AbstractString, prefix::AbstractString="")
        unique_prefix = _gensym_string()
        prefix = isempty(prefix) ? unique_prefix : string(prefix, "_", unique_prefix)
        return new(pwd, prefix, Dict{Symbol,Sandbox}())
    end
end

function Base.get!(s::NamedSandboxes, name::Union{AbstractString,Nothing}=nothing)
    sym = if isnothing(name) || isempty(name)
        Symbol("__", s._prefix, "__", _gensym_string())
    else
        Symbol("__", s._prefix, "__named__", name)
    end
    # Either fetch and return an existing sandbox from the meta dictionary (based on the generated name),
    # or initialize a new clean one, which gets stored in meta for future re-use.
    return get!(() -> Sandbox(sym; workingdirectory=s._pwd), s._sandboxes, sym)
end
