# Block configuration for inner load blocks within a stage
#
# Two modes are supported:
#   :parallel       - single water balance per hydro with block-weight aggregation
#   :chronological  - per-block water balances with intermediate storage variables

struct Block
    name::String
    duration_hours::Float64
end

struct BlockConfig
    mode::Symbol
    blocks::Vector{Block}
end

"""
    default_block_config() -> BlockConfig

Return a default BlockConfig with a single unnamed block (duration set later at build time).
The single block has duration_hours = 0.0 as a sentinel; the actual duration comes from
the graph node's tau at build time.
"""
function default_block_config()::BlockConfig
    return BlockConfig(:parallel, Block[])
end

"""
    has_blocks(bc::BlockConfig) -> Bool

Return true if the user explicitly configured blocks (non-empty blocks vector).
"""
function has_blocks(bc::BlockConfig)::Bool
    return !isempty(bc.blocks)
end

"""
    num_blocks(bc::BlockConfig) -> Int

Return the number of blocks. Returns 1 when no explicit blocks are configured.
"""
function num_blocks(bc::BlockConfig)::Int
    return has_blocks(bc) ? length(bc.blocks) : 1
end

"""
    get_block_names(bc::BlockConfig) -> Vector{String}

Return block names. Returns ["1"] when no explicit blocks are configured.
"""
function get_block_names(bc::BlockConfig)::Vector{String}
    return has_blocks(bc) ? [b.name for b in bc.blocks] : ["1"]
end

"""
    get_block_durations(bc::BlockConfig, tau::Float64) -> Vector{Float64}

Return per-block durations in hours. When no explicit blocks are configured,
returns [tau] (the full stage duration).
"""
function get_block_durations(bc::BlockConfig, tau::Float64)::Vector{Float64}
    return has_blocks(bc) ? [b.duration_hours for b in bc.blocks] : [tau]
end

"""
    get_block_weights(tau_k::Vector{Float64}) -> Vector{Float64}

Compute block weights w_k = tau_k / sum(tau_k).
"""
function get_block_weights(tau_k::Vector{Float64})::Vector{Float64}
    total = sum(tau_k)
    return total > 0.0 ? tau_k ./ total : ones(length(tau_k)) ./ length(tau_k)
end

# --- Block config parsing ---

const VALID_BLOCK_MODES = Set(["parallel", "chronological"])

function __validate_block_mode!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "mode")
        push!(e, AssertionError("Blocks config missing required key 'mode'"))
        return false
    end
    mode = d["mode"]
    if !(mode isa String)
        push!(e, AssertionError("Blocks config 'mode' must be a String, got $(typeof(mode))"))
        return false
    end
    if !(mode in VALID_BLOCK_MODES)
        push!(e, ErrorException("Blocks config 'mode' must be 'parallel' or 'chronological', got '$mode'"))
        return false
    end
    return true
end

function __validate_block_definitions!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "definitions")
        push!(e, AssertionError("Blocks config missing required key 'definitions'"))
        return false
    end
    defs = d["definitions"]
    if !(defs isa Vector)
        push!(e, AssertionError("Blocks config 'definitions' must be a Vector"))
        return false
    end
    if isempty(defs)
        push!(e, AssertionError("Blocks config 'definitions' must have at least one block"))
        return false
    end

    valid = true
    names_seen = Set{String}()
    for (i, def) in enumerate(defs)
        if !(def isa Dict)
            push!(e, AssertionError("Block definition $i must be a Dict"))
            valid = false
            continue
        end
        if !haskey(def, "name") || !(def["name"] isa String)
            push!(e, AssertionError("Block definition $i missing or invalid 'name'"))
            valid = false
        else
            if def["name"] in names_seen
                push!(e, AssertionError("Block definition $i has duplicate name '$(def["name"])'"))
                valid = false
            end
            push!(names_seen, def["name"])
        end
        if !haskey(def, "duration_hours") || !(def["duration_hours"] isa Real)
            push!(e, AssertionError("Block definition $i missing or invalid 'duration_hours'"))
            valid = false
        elseif def["duration_hours"] <= 0
            push!(e, AssertionError("Block definition $i 'duration_hours' must be positive, got $(def["duration_hours"])"))
            valid = false
        end
    end
    return valid
end

"""
    BlockConfig(d::Dict{String,Any}, e::CompositeException) -> Union{BlockConfig, Nothing}

Construct a BlockConfig from a dictionary (the `"blocks"` key in scenarios JSON).
"""
function BlockConfig(d::Dict{String,Any}, e::CompositeException)::Union{BlockConfig,Nothing}
    valid_mode = __validate_block_mode!(d, e)
    valid_defs = __validate_block_definitions!(d, e)
    if !(valid_mode && valid_defs)
        return nothing
    end

    mode = Symbol(d["mode"])
    blocks = Block[
        Block(def["name"], Float64(def["duration_hours"]))
        for def in d["definitions"]
    ]

    return BlockConfig(mode, blocks)
end
