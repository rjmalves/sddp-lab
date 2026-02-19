using Test
using SDDPlab

include("utils.jl")

example_dir = joinpath(@__DIR__, "..", "example", "1dtoy")
example_data_dir = joinpath(example_dir, "data")

test_files = __list_test_files(".")

filter_pattern = get(ENV, "TEST_FILTER", "")
if !isempty(filter_pattern)
    test_files = filter(f -> occursin(filter_pattern, f), test_files)
    @info "TEST_FILTER=\"$filter_pattern\" — running $(length(test_files)) test files"
end

@testset "SDDPlab" begin
    for tf in test_files
            include(tf)
    end
end
