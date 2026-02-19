using SHA
using Dates
using JSON
import Pkg

"""
    EnvironmentSnapshot

Captures a point-in-time snapshot of the Julia execution environment for
reproducibility tracking.

# Fields
- `julia_version`: Julia version string (e.g. `"1.10.2"`).
- `os_machine`: OS and architecture string from `Sys.MACHINE`.
- `package_versions`: Dict mapping key package names to their version strings.
- `num_threads`: Number of Julia threads at capture time.
- `timestamp`: ISO 8601 timestamp string (UTC).

# Example
```julia
env = capture_environment()
println(env.julia_version)  # "1.10.2"
```
"""
struct EnvironmentSnapshot
    julia_version::String
    os_machine::String
    package_versions::Dict{String,String}
    num_threads::Int
    timestamp::String
end

"""
    capture_environment() -> EnvironmentSnapshot

Capture a snapshot of the current Julia execution environment.

Reads key package versions from `Pkg.dependencies()`. If that call fails
(e.g. in a non-standard environment), package versions are recorded as
`"unknown"` and a warning is logged.

# Example
```julia
env = capture_environment()
println(env.julia_version)   # e.g. "1.10.2"
println(env.num_threads)     # e.g. 4
```
"""
function capture_environment()::EnvironmentSnapshot
    target_packages = Set(["SDDP", "JuMP", "HiGHS", "GLPK", "DataFrames", "CSV"])
    pkg_versions = Dict{String,String}()

    try
        deps = Pkg.dependencies()
        for (_, info) in deps
            if info.name in target_packages
                pkg_versions[info.name] = string(info.version)
            end
        end
    catch ex
        @warn "Could not read package versions from Pkg.dependencies()" exception = ex
    end

    return EnvironmentSnapshot(
        string(VERSION),
        Sys.MACHINE,
        pkg_versions,
        Threads.nthreads(),
        Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SSZ"),
    )
end

"""
    hash_config(config_dict::Dict{String,Any}) -> String

Compute a deterministic SHA-256 hash of `config_dict` serialized as compact
JSON with recursively sorted keys.

Key sorting is mandatory: it ensures that two `Dict` objects with identical
entries but different insertion orders (which affects Julia's hash-table
iteration order) produce identical hashes.

Returns a lowercase hexadecimal string of 64 characters.

# Example
```julia
d1 = Dict{String,Any}("z" => 1, "a" => 2)
d2 = Dict{String,Any}("a" => 2, "z" => 1)
@assert hash_config(d1) == hash_config(d2)
```
"""
function hash_config(config_dict::Dict{String,Any})::String
    canonical = _canonical_json(config_dict)
    return bytes2hex(SHA.sha256(Vector{UInt8}(codeunits(canonical))))
end

"""
    write_run_metadata(output_dir, config_name, config_dict, env; seeds)

Write a `metadata.json` file to `<output_dir>/<config_name>/metadata.json`.

The file contains four top-level keys:
- `"config_hash"`: SHA-256 of the canonically-serialized config dict.
- `"config"`: the full engine configuration dict as-is.
- `"environment"`: the environment snapshot as a plain dict.
- `"seeds"`: any seeds extracted from the study (e.g. `"saa_seed"`).

Write failures are caught and logged as warnings; they do NOT abort the
calling experiment run.

# Arguments
- `output_dir`: Parent directory (the experiment output root).
- `config_name`: Name of the configuration; used as the subdirectory name.
- `config_dict`: Raw engine params dict (before `Study` construction).
- `env`: An `EnvironmentSnapshot` from `capture_environment()`.
- `seeds`: Optional `Dict{String,Any}` of seed values (default: empty dict).

# Example
```julia
env = capture_environment()
write_run_metadata("/tmp/exp", "iter3", params_dict, env; seeds=Dict("saa_seed"=>42))
```
"""
function write_run_metadata(
    output_dir::String,
    config_name::String,
    config_dict::Dict{String,Any},
    env::EnvironmentSnapshot;
    seeds::Dict{String,Any} = Dict{String,Any}(),
)
    filepath = joinpath(output_dir, config_name, "metadata.json")
    metadata = Dict{String,Any}(
        "config_hash" => hash_config(config_dict),
        "config" => config_dict,
        "environment" => Dict{String,Any}(
            "julia_version" => env.julia_version,
            "os_machine" => env.os_machine,
            "package_versions" => env.package_versions,
            "num_threads" => env.num_threads,
            "timestamp" => env.timestamp,
        ),
        "seeds" => seeds,
    )
    try
        open(filepath, "w") do io
            JSON.print(io, metadata, 2)
        end
    catch ex
        @warn "Failed to write run metadata" config_name filepath exception = ex
    end
    return nothing
end

"""
    verify_reproducibility(dir_a, dir_b) -> Bool

Compare two run output directories by reading their `metadata.json` files and
comparing the `config_hash` fields.

Returns `true` when both files exist and their `config_hash` values are
identical. Returns `false` (with a `@warn`) in all other cases:
- Either directory is missing `metadata.json`.
- Either file cannot be parsed as JSON.
- The `config_hash` field is absent or differs.

When hashes match but `num_threads` differ between the two environments, a
`@warn` is emitted to flag potential non-determinism in threaded runs.

# Example
```julia
ok = verify_reproducibility("/tmp/exp/run1/iter3", "/tmp/exp/run2/iter3")
```
"""
function verify_reproducibility(dir_a::String, dir_b::String)::Bool
    meta_a = _load_metadata(dir_a)
    meta_b = _load_metadata(dir_b)

    meta_a === nothing && return false
    meta_b === nothing && return false

    hash_a = get(meta_a, "config_hash", nothing)
    hash_b = get(meta_b, "config_hash", nothing)

    if hash_a === nothing
        @warn "verify_reproducibility: \"config_hash\" missing in metadata for \"$dir_a\""
        return false
    end
    if hash_b === nothing
        @warn "verify_reproducibility: \"config_hash\" missing in metadata for \"$dir_b\""
        return false
    end

    if hash_a != hash_b
        @warn "verify_reproducibility: config hashes differ" dir_a hash_a dir_b hash_b
        return false
    end

    # Hashes match — check for environment differences that may affect results.
    env_a = get(meta_a, "environment", nothing)
    env_b = get(meta_b, "environment", nothing)

    if env_a isa Dict && env_b isa Dict
        threads_a = get(env_a, "num_threads", nothing)
        threads_b = get(env_b, "num_threads", nothing)
        if threads_a !== nothing && threads_b !== nothing && threads_a != threads_b
            @warn "verify_reproducibility: configs are identical but thread counts differ" dir_a threads_a dir_b threads_b
        end
    end

    return true
end

function _canonical_json(v)::String
    io = IOBuffer()
    _write_json_sorted(io, v)
    return String(take!(io))
end

function _write_json_sorted(io::IO, d::Dict)
    write(io, '{')
    ks = sort!(collect(keys(d)))
    for (i, k) in enumerate(ks)
        i > 1 && write(io, ',')
        JSON.print(io, string(k))
        write(io, ':')
        _write_json_sorted(io, d[k])
    end
    write(io, '}')
end

function _write_json_sorted(io::IO, v::AbstractVector)
    write(io, '[')
    for (i, item) in enumerate(v)
        i > 1 && write(io, ',')
        _write_json_sorted(io, item)
    end
    write(io, ']')
end

function _write_json_sorted(io::IO, v)
    JSON.print(io, v)
end

function _load_metadata(dir::String)::Union{Dict{String,Any},Nothing}
    filepath = joinpath(dir, "metadata.json")
    if !isfile(filepath)
        @warn "verify_reproducibility: metadata.json not found" dir filepath
        return nothing
    end
    try
        return JSON.parsefile(filepath)
    catch ex
        @warn "verify_reproducibility: failed to parse metadata.json" dir filepath exception = ex
        return nothing
    end
end
