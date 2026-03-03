function generate_saa(
    scenarios::ScenariosData, num_stages::Integer, seed::Integer, branchings::Integer
)
    initial_season = scenarios.initial_season
    result = Dict{Int,Vector{Vector{Vector{Float64}}}}()
    for (state, process) in scenarios.inflow.stochastic_process
        state_seed = seed + (state - 1) * 7919  # prime offset ensures per-state independence
        result[state] = StochasticProcess.generate_saa(
            process, initial_season, num_stages, branchings, state_seed
        )
    end
    return result
end

function Lab.validate(
    model::SDDPModel, validation::OutOfSampleValidation, files::Vector{InputModule}
)::SDDPValidationTaskArtifact
    scenarios = get_scenarios(files)
    system = get_system(files)
    graph = get_graph(scenarios)
    num_stages = get_number_of_stages(graph)
    scaling = model.scaling

    oos_saa = generate_saa(scenarios, num_stages, validation.seed, validation.branchings)

    s_flow = get_scaling_factor(scaling, FLOW_SCALE)
    if s_flow != DEFAULT_SCALING_FACTOR
        for (state, saa_stages) in oos_saa
            for stage_idx in eachindex(saa_stages)
                saa_stages[stage_idx] = saa_stages[stage_idx] ./ s_flow
            end
        end
    end

    # Always truncate to non-negative: negative inflows are physically meaningless
    # and the validate function does not receive the engine's InflowNonNegativity setting.
    for (state, saa_stages) in oos_saa
        for stage_idx in eachindex(saa_stages)
            saa_stages[stage_idx] = [max.(0.0, omega) for omega in saa_stages[stage_idx]]
        end
    end

    try
        SDDP.add_all_cuts(model.policy_graph)
    catch ex
        @warn "Failed to add all cuts for validation" exception = (ex, catch_backtrace())
    end

    sampler = SDDP.OutOfSampleMonteCarlo(
        model.policy_graph; use_insample_transition = true
    ) do node
        stage = __extract_stage(node)
        markov_state = __extract_markov_state(node)
        oos_stage = oos_saa[markov_state][stage]
        return [
            SDDP.Noise(oos_stage[b], 1.0 / length(oos_stage)) for b in eachindex(oos_stage)
        ]
    end

    parallel_scheme = generate_parallel_scheme(validation.parallel_scheme)

    @info "Running out-of-sample validation"
    sims = SDDP.simulate(
        model.policy_graph,
        validation.num_simulations,
        [
            THERMAL_GENERATION,
            THERMAL_GENERATION_COST,
            INFLOW,
            TURBINED_FLOW,
            SPILLAGE,
            OUTFLOW,
            HYDRO_GENERATION,
            STORED_VOLUME,
            DEFICIT,
            NET_EXCHANGE,
            VERTEX_COVERAGE_DISTANCE,
        ];
        sampling_scheme = sampler,
        custom_recorders = Dict{Symbol,Function}(
            MARGINAL_COST => (sp::JuMP.Model) -> JuMP.dual.(sp[LOAD_BALANCE]),
            WATER_VALUE => (sp::JuMP.Model) -> JuMP.dual.(sp[HYDRO_BALANCE]),
            TOTAL_COST => (sp::JuMP.Model) -> JuMP.objective_value(sp),
        ),
        parallel_scheme = parallel_scheme,
        skip_undefined_variables = true,
    )

    stats = _compute_validation_statistics(sims)

    return SDDPValidationTaskArtifact(sims, scaling, stats)
end

function _compute_validation_statistics(
    sims::Vector{Vector{Dict{Symbol,Any}}}
)::Dict{String,Float64}
    total_costs = Float64[sum(Float64(stage[TOTAL_COST]) for stage in sim) for sim in sims]

    n = length(total_costs)
    mu = Statistics.mean(total_costs)
    sigma = n > 1 ? Statistics.std(total_costs) : 0.0
    se = n > 1 ? sigma / sqrt(n) : 0.0

    # For 95% CI: use z=1.96 for n >= 30, approximate t-quantile otherwise
    z = n >= 30 ? 1.96 : _t_quantile_95(n - 1)

    return Dict{String,Float64}(
        "mean_cost" => mu,
        "std_cost" => sigma,
        "ci_lower_95" => mu - z * se,
        "ci_upper_95" => mu + z * se,
        "p05_cost" => Statistics.quantile(total_costs, 0.05),
        "p50_cost" => Statistics.quantile(total_costs, 0.50),
        "p95_cost" => Statistics.quantile(total_costs, 0.95),
        "max_cost" => maximum(total_costs),
        "min_cost" => minimum(total_costs),
        "num_simulations" => Float64(n),
    )
end

# Approximate 97.5th percentile of the t-distribution (for two-sided 95% CI).
# Lookup table for small df, asymptotic z=1.96 for large df.
function _t_quantile_95(df::Integer)::Float64
    if df <= 0
        return Inf
    elseif df == 1
        return 12.706
    elseif df == 2
        return 4.303
    elseif df == 3
        return 3.182
    elseif df == 4
        return 2.776
    elseif df == 5
        return 2.571
    elseif df <= 10
        # Interpolation table for df 6..10
        table = [2.447, 2.365, 2.306, 2.262, 2.228]
        return table[df - 5]
    elseif df <= 20
        # Interpolation table for df 11..20
        table = [2.201, 2.179, 2.160, 2.145, 2.131, 2.120, 2.110, 2.101, 2.093, 2.086]
        return table[df - 10]
    elseif df <= 29
        # Approximate for df 21..29
        return 2.086 - (df - 20) * (2.086 - 2.045) / 9
    else
        return 1.96
    end
end

function Lab.save_validation(
    artifact::SDDPValidationTaskArtifact,
    path::String,
    format::TaskResultsFormat,
    files::Vector{InputModule},
)
    writer = get_writer(format)
    extension = get_extension(format)
    curdir = pwd()
    try
        cd(path)
        simulations = _unscale_simulations(artifact.simulations, artifact.scaling)
        __write_validation_simulation_results(
            simulations, get_system(files), files, writer, extension
        )
        __write_validation_statistics(artifact.statistics, writer, extension)
    finally
        cd(curdir)
    end
    return nothing
end

function __write_validation_simulation_results(
    simulations::Vector{Vector{Dict{Symbol,Any}}},
    system::SystemData,
    files::Vector{InputModule},
    writer::Function,
    extension::String,
)
    @info "Writing validation simulation results"

    entity_column = "entity_id"
    num_simulations = size(simulations)[1]

    # Build per-stage block duration lookup from ScenariosData
    stage_block_durations = __build_stage_block_durations(files)

    map_variable_output = Dict(
        "validation_operation_buses" => [DEFICIT, MARGINAL_COST],
        "validation_operation_thermals" => [THERMAL_GENERATION, THERMAL_GENERATION_COST],
        "validation_operation_noncontrollables" => [NC_GENERATION, NC_CURTAILMENT],
        "validation_operation_contracts" => [CONTRACT_DISPATCH],
        "validation_operation_pumping" => [PUMPED_FLOW, PUMP_POWER],
        "validation_operation_lines" => [NET_EXCHANGE],
        "validation_operation_hydros" => [
            STORED_VOLUME,
            INFLOW,
            INFLOW_SLACK,
            NOISE_ADJUSTMENT_SLACK,
            TURBINED_FLOW,
            OUTFLOW,
            SPILLAGE,
            WATER_VALUE,
            HYDRO_GENERATION,
        ],
        "validation_operation_system" =>
            [STAGE_COST, FUTURE_COST, TOTAL_COST, VERTEX_COVERAGE_DISTANCE],
    )

    map_variable_entities = Dict(
        DEFICIT => get_buses_entities(system),
        MARGINAL_COST => get_buses_entities(system),
        THERMAL_GENERATION => get_thermals_entities(system),
        THERMAL_GENERATION_COST => get_thermals_entities(system),
        NC_GENERATION => get_noncontrollables_entities(system),
        NC_CURTAILMENT => get_noncontrollables_entities(system),
        CONTRACT_DISPATCH => get_energycontracts_entities(system),
        PUMPED_FLOW => get_pumpingstations_entities(system),
        PUMP_POWER => get_pumpingstations_entities(system),
        NET_EXCHANGE => get_lines_entities(system),
        HYDRO_GENERATION => get_hydros_entities(system),
        STORED_VOLUME => get_hydros_entities(system),
        INFLOW => get_hydros_entities(system),
        INFLOW_SLACK => get_hydros_entities(system),
        NOISE_ADJUSTMENT_SLACK => get_hydros_entities(system),
        TURBINED_FLOW => get_hydros_entities(system),
        OUTFLOW => get_hydros_entities(system),
        SPILLAGE => get_hydros_entities(system),
        WATER_VALUE => get_hydros_entities(system),
    )

    for (key, variables) in map_variable_output
        df = DataFrames.DataFrame()
        for variable in variables
            if !__variable_exists_in_sim(simulations, variable)
                continue
            end
            if variable in keys(map_variable_entities)
                entities_ids = map(u -> u.id, map_variable_entities[variable])
            else
                entities_ids = Vector{Int64}([1])
            end
            if length(entities_ids) == 0
                break
            end
            if variable == STORED_VOLUME
                for (direction, in_state, out_state) in
                    zip(["_IN", "_OUT"], [true, false], [false, true])
                    __increase_dataframe!(
                        df,
                        variable,
                        String(variable) * direction,
                        entities_ids,
                        entity_column,
                        simulations,
                        stage_block_durations,
                        in_state,
                        out_state,
                    )
                end
            else
                __increase_dataframe!(
                    df,
                    variable,
                    string(variable),
                    entities_ids,
                    entity_column,
                    simulations,
                    stage_block_durations,
                )
            end
        end
        if size(df)[1] == 0
            continue
        end
        df = DataFrames.stack(df, string.(Array((1:num_simulations))))
        DataFrames.rename!(df, "variable" => "scenario")
        df[!, "scenario"] = parse.(Int64, df[!, "scenario"])
        df[!, "variable_name"] =
            replace.(df[!, "variable_name"], "stage_objective" => "STAGE_COST")
        df[!, "variable_name"] =
            replace.(df[!, "variable_name"], "bellman_term" => "FUTURE_COST")
        df[!, "variable_name"] =
            replace.(
                df[!, "variable_name"],
                "bellman_vertex_coverage_distance" => "VERTEX_COVERAGE_DISTANCE",
            )
        sort!(
            df,
            ["stage", "variable_name", entity_column, "block_index", "scenario"];
            lt = isless,
        )

        @info "Writing $(key * extension)"
        writer(key * extension, df)
    end

    return nothing
end

function __write_validation_statistics(
    statistics::Dict{String,Float64}, writer::Function, extension::String
)
    @info "Writing validation_statistics$(extension)"
    df = DataFrames.DataFrame(;
        metric_name = collect(keys(statistics)), value = collect(values(statistics))
    )
    sort!(df, :metric_name)
    writer("validation_statistics" * extension, df)
    return nothing
end
