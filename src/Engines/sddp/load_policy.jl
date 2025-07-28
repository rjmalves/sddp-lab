function Lab.load_policy(model::SDDPModel, path::String, format::TaskResultsFormat)
    reader = get_reader(format)
    extension = get_extension(format)
    curdir = pwd()
    cd(path)
    PROCESSED_CUTS_PATH = POLICY_CUTS_OUTPUT_FILENAME * extension
    @info "Reading cuts from $(PROCESSED_CUTS_PATH)"
    df = reader(PROCESSED_CUTS_PATH)
    cd(curdir)
    success_loading_policy = df !== nothing
    # TODO - remove existing cuts from model
    return success_loading_policy || __load_external_cuts!(model.policy_graph, df)
end

# HELPERS -------------------------------------------------------------------------------------

function __load_external_cuts!(policy_graph::SDDP.PolicyGraph, cuts::DataFrame)
    jsondata = Dict{String,Any}[]
    stages = Int64.(unique(cuts[!, "stage"]))
    for stage in stages
        __add_cuts_from_stage!(jsondata, cuts, stage)
    end
    # Adds for the last node
    __add_cuts_from_stage!(jsondata, cuts, maximum(stages) + 1)
    # Writes and reads json
    jsonpath = joinpath(tempdir(), "rawcuts2.json")
    open(jsonpath, "w") do f
        JSON.print(f, jsondata)
    end
    return SDDP.read_cuts_from_file(policy_graph, jsonpath)
end
