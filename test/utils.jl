
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

function __remove_key(d, k)
    out = copy(d)
    delete!(out, k)
end

function __modif_key(d, k, v)
    out = copy(d)
    out[k] = v
    return out
end

function __renew(d)
    return (copy(d), CompositeException())
end