module Core

include("types.jl")
include("variables.jl")

function get_input_module(i::Vector{InputModule}, kind::Type)::InputModule
    index = findfirst(x -> isa(x, kind), i)
    return i[index]
end

export InputModule, get_input_module

end