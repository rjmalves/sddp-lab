using Test
using SDDPlab

include("utils.jl")

test_files = __list_test_files(".")

for tf in test_files
    include(tf)
end