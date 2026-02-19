"""
    deep_merge(base, override)

Recursively merge two `Dict{String,Any}` values. When both `base` and `override` contain a
`Dict{String,Any}` for the same key the function recurses; for all other value types the
override value wins outright.

Returns a new dict; neither argument is mutated.

# Examples
```julia
base     = Dict("a" => 1, "b" => Dict("x" => 10, "y" => 20))
override = Dict("b" => Dict("x" => 99), "c" => 3)
result   = deep_merge(base, override)
# => Dict("a" => 1, "b" => Dict("x" => 99, "y" => 20), "c" => 3)
```
"""
function deep_merge(
    base::Dict{String,Any}, override::Dict{String,Any}
)::Dict{String,Any}
    result = copy(base)
    for (k, v) in override
        if haskey(result, k) &&
           isa(result[k], Dict{String,Any}) &&
           isa(v, Dict{String,Any})
            result[k] = deep_merge(result[k], v)
        else
            result[k] = v
        end
    end
    return result
end
