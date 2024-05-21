
function __list_test_files(test_dir)

    test_files = Vector{String}()

    for (root, dirs, files) in walkdir(test_dir)
        for file in files
            if file[1:5] == "test-"
                push!(test_files, joinpath(root, file))
            end
        end
    end

    return test_files
end