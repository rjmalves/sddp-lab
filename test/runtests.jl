using Test
using SDDPlab

include("utils.jl")

example_dir = joinpath(@__DIR__, "..", "data-refactor")
example_data_dir = joinpath(example_dir, "data")

test_files = __list_test_files(".")

example_dir = joinpath(@__DIR__, "..", "data-refactor")
example_data_dir = joinpath(example_dir, "data")

for tf in test_files
    include(tf)
end
