function DiagnosticsConfig(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, DIAGNOSTICS_SCHEMA, e)
    valid_cross = valid && __validate_diagnostics_halt_ge_warn!(d, e)

    return if valid_cross
        DiagnosticsConfig(
            d["run_numerical_report"],
            d["warn_threshold"],
            d["halt_threshold"],
        )
    else
        nothing
    end
end

function __build_diagnostics!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "diagnostics")
        d["diagnostics"] = DiagnosticsConfig(false, 1e6, 1e10)
        return true
    end

    diag = d["diagnostics"]
    if !(diag isa Dict)
        push!(
            e,
            ErrorException(
                "Key 'diagnostics' must be a Dict{String,Any}, got $(typeof(diag))",
            ),
        )
        return false
    end

    diag_d = convert(Dict{String,Any}, diag)
    result = DiagnosticsConfig(diag_d, e)
    if result === nothing
        return false
    end

    d["diagnostics"] = result
    return true
end

const VALID_SUBPROBLEM_FORMATS = ["mof", "lp", "mps"]

function DebugConfig(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, DEBUG_CONFIG_SCHEMA, e)
    if !valid
        return nothing
    end

    write_subproblems = get(d, "write_subproblems", false)
    subproblem_nodes_raw = get(d, "subproblem_nodes", Any[])
    subproblem_format = get(d, "subproblem_format", "mof")
    deterministic_equivalent = get(d, "deterministic_equivalent", false)
    det_equiv_time_limit = get(d, "det_equiv_time_limit", 60.0)

    if !(subproblem_nodes_raw isa Vector)
        push!(
            e,
            ErrorException(
                "Key 'subproblem_nodes' must be a Vector, got $(typeof(subproblem_nodes_raw))",
            ),
        )
        return nothing
    end

    if !(subproblem_format in VALID_SUBPROBLEM_FORMATS)
        push!(
            e,
            AssertionError(
                "subproblem_format ($subproblem_format) must be one of: $(join(VALID_SUBPROBLEM_FORMATS, ", "))",
            ),
        )
        return nothing
    end

    return DebugConfig(
        write_subproblems,
        Vector{Any}(subproblem_nodes_raw),
        subproblem_format,
        deterministic_equivalent,
        Float64(det_equiv_time_limit),
    )
end

function __build_debug!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "debug")
        d["debug"] = DebugConfig(false, Any[], "mof", false, 60.0)
        return true
    end

    dbg = d["debug"]
    if !(dbg isa Dict)
        push!(
            e,
            ErrorException(
                "Key 'debug' must be a Dict{String,Any}, got $(typeof(dbg))",
            ),
        )
        return false
    end

    dbg_d = convert(Dict{String,Any}, dbg)
    result = DebugConfig(dbg_d, e)
    if result === nothing
        return false
    end

    d["debug"] = result
    return true
end

function SolverConfig(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, SOLVER_CONFIG_SCHEMA, e)
    if !valid
        return nothing
    end
    attrs = get(d, "attributes", Dict{String,Any}())
    if !(attrs isa Dict)
        push!(
            e,
            ErrorException(
                "Key 'attributes' must be a Dict{String,Any}, got $(typeof(attrs))",
            ),
        )
        return nothing
    end
    attrs_d = convert(Dict{String,Any}, attrs)
    return SolverConfig(d["name"], attrs_d)
end

function __build_solver!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "solver")
        d["solver"] = SolverConfig("HiGHS", Dict{String,Any}())
        return true
    end

    solver = d["solver"]
    if !(solver isa Dict)
        push!(
            e,
            ErrorException(
                "Key 'solver' must be a Dict{String,Any}, got $(typeof(solver))",
            ),
        )
        return false
    end

    solver_d = convert(Dict{String,Any}, solver)
    result = SolverConfig(solver_d, e)
    if result === nothing
        return false
    end

    d["solver"] = result
    return true
end

function IterationLimit(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, ITERATION_LIMIT_SCHEMA, e)
    return valid ? IterationLimit(d["num_iterations"]) : nothing
end

function TimeLimit(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, TIME_LIMIT_SCHEMA, e)
    return valid ? TimeLimit(d["time_seconds"]) : nothing
end

function LowerBoundStability(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, LOWER_BOUND_STABILITY_SCHEMA, e)
    return valid ? LowerBoundStability(d["threshold"], d["num_iterations"]) : nothing
end

function Statistical(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, STATISTICAL_SCHEMA, e)
    return valid ?
           Statistical(d["num_replications"], d["iteration_period"], d["z_score"]) : nothing
end

function SimulationStopping(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, SIMULATION_STOPPING_SCHEMA, e)
    return valid ? SimulationStopping(d["replications"], d["period"]) : nothing
end

function FirstStageStopping(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, FIRST_STAGE_STOPPING_SCHEMA, e)
    return valid ? FirstStageStopping(d["atol"], d["iterations"]) : nothing
end

function StoppingChain(d::Dict{String,Any}, e::CompositeException)
    valid_key = __validate_stopping_chain_rules_key_type!(d, e)
    if !valid_key
        return nothing
    end

    valid_internals = __build_stopping_chain_internals!(d, e)
    if !valid_internals
        return nothing
    end

    return StoppingChain(d["rules"]::Vector{StoppingCriteria})
end

function Convergence(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_stopping_criteria!(d, e)
    valid_schema = valid_internals && validate_schema!(d, CONVERGENCE_SCHEMA, e)
    valid_keys_types = valid_schema && __validate_convergence_keys_types!(d, e)
    valid_cross = valid_keys_types && __validate_convergence_min_max!(d, e)

    return if valid_cross
        sc = d["stopping_criteria"]
        sc_vec = sc isa Vector{StoppingCriteria} ? sc : StoppingCriteria[sc]
        Convergence(d["min_iterations"], d["max_iterations"], sc_vec)
    else
        nothing
    end
end

function Serial(::Dict{String,Any}, ::CompositeException)
    return Serial()
end

function Asynchronous(::Dict{String,Any}, ::CompositeException)
    return Asynchronous()
end

function Threaded(::Dict{String,Any}, ::CompositeException)
    return Threaded()
end

function Expectation(::Dict{String,Any}, ::CompositeException)
    return Expectation()
end

function WorstCase(::Dict{String,Any}, ::CompositeException)
    return WorstCase()
end

function AVaR(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, AVAR_SCHEMA, e)
    return valid ? AVaR(d["alpha"]) : nothing
end

function CVaR(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, CVAR_SCHEMA, e)
    return valid ? CVaR(d["alpha"], d["lambda"]) : nothing
end

function Entropic(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, ENTROPIC_SCHEMA, e)
    return valid ? Entropic(d["theta"]) : nothing
end

function WassersteinRM(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, WASSERSTEIN_RM_SCHEMA, e)
    return valid ? WassersteinRM(d["alpha"]) : nothing
end

function ModifiedChiSquared(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, MODIFIED_CHI_SQUARED_SCHEMA, e)
    return valid ? ModifiedChiSquared(d["radius"], d["minimum_std"]) : nothing
end

function ConvexCombination(d::Dict{String,Any}, e::CompositeException)
    valid_key = __validate_convex_combination_measures_key_type!(d, e)
    if !valid_key
        return nothing
    end

    valid_internals = __build_convex_combination_internals!(d, e)
    if !valid_internals
        return nothing
    end

    measures = d["measures"]::Vector{Tuple{Real,RiskMeasure}}
    valid_weights = __validate_convex_combination_weights!(measures, e)

    return valid_weights ? ConvexCombination(measures) : nothing
end

function DefaultSampling(::Dict{String,Any}, ::CompositeException)
    return DefaultSampling()
end

function InSampleMC(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, INSAMPLE_MC_SCHEMA, e)
    return valid ? InSampleMC(d["max_depth"], d["terminate_on_dummy_leaf"]) : nothing
end

function PSRSampling(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, PSR_SAMPLING_SCHEMA, e)
    return valid ? PSRSampling(d["num_samples"]) : nothing
end

function DefaultDuality(::Dict{String,Any}, ::CompositeException)
    return DefaultDuality()
end

function ContinuousConicDualityHandler(::Dict{String,Any}, ::CompositeException)
    return ContinuousConicDualityHandler()
end

function StrengthenedConicDualityHandler(::Dict{String,Any}, ::CompositeException)
    return StrengthenedConicDualityHandler()
end

function LagrangianDualityHandler(::Dict{String,Any}, ::CompositeException)
    return LagrangianDualityHandler()
end

function BanditDualityHandler(d::Dict{String,Any}, e::CompositeException)
    valid_key = __validate_bandit_duality_handlers_key_type!(d, e)
    if !valid_key
        return nothing
    end

    valid_internals = __build_bandit_duality_internals!(d, e)
    if !valid_internals
        return nothing
    end

    handlers = d["handlers"]::Vector{DualityHandler}
    valid_count = __validate_bandit_duality_handler_count!(handlers, e)

    return valid_count ? BanditDualityHandler(handlers) : nothing
end

function DefaultForwardPassStrategy(::Dict{String,Any}, ::CompositeException)
    return DefaultForwardPassStrategy()
end

function RevisitingForwardPassStrategy(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, REVISITING_FORWARD_PASS_SCHEMA, e)
    return valid ? RevisitingForwardPassStrategy(d["period"]) : nothing
end

function RiskAdjustedForwardPassStrategy(::Dict{String,Any}, ::CompositeException)
    return RiskAdjustedForwardPassStrategy()
end

function RegularizedForwardPassStrategy(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, REGULARIZED_FORWARD_PASS_SCHEMA, e)
    return valid ? RegularizedForwardPassStrategy(d["rho"]) : nothing
end

function SingleCut(::Dict{String,Any}, ::CompositeException)
    return SingleCut()
end

function MultiCut(::Dict{String,Any}, ::CompositeException)
    return MultiCut()
end

function NoScaling(::Dict{String,Any}, ::CompositeException)
    return NoScaling()
end

function AutoScaling(::Dict{String,Any}, ::CompositeException)
    return AutoScaling()
end

function TrainingLogConfig(d::Dict{String,Any}, e::CompositeException)
    valid = validate_schema!(d, TRAINING_LOG_CONFIG_SCHEMA, e)

    return if valid
        TrainingLogConfig(
            get(d, "log_file", ""),
            get(d, "log_frequency", 1),
            get(d, "log_every_iteration", false),
            get(d, "print_level", 1),
        )
    else
        nothing
    end
end

function __build_logging!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "logging")
        d["logging"] = TrainingLogConfig("", 1, false, 1)
        return true
    end

    logging = d["logging"]
    if !(logging isa Dict)
        push!(
            e,
            ErrorException(
                "Key 'logging' must be a Dict{String,Any}, got $(typeof(logging))",
            ),
        )
        return false
    end

    logging_d = convert(Dict{String,Any}, logging)
    result = TrainingLogConfig(logging_d, e)
    if result === nothing
        return false
    end

    d["logging"] = result
    return true
end

function SDDPPolicyTaskDefinition(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_sddp_policy_task_definition_internals_from_dicts!(d, e)
    valid_keys_types =
        valid_internals && __validate_sddp_policy_task_definition_keys_types!(d, e)

    return if valid_keys_types
        SDDPPolicyTaskDefinition(
            d["convergence"],
            d["risk_measure"],
            d["parallel_scheme"],
            d["sampling_scheme"],
            d["duality_handler"],
            d["forward_pass"],
            d["cut_type"],
            d["scaling"],
            d["logging"],
        )
    else
        nothing
    end
end

function SDDPSimulationTaskDefinition(d::Dict{String,Any}, e::CompositeException)
    valid_internals = __build_sddp_simulation_task_definition_internals_from_dicts!(d, e)
    valid_schema =
        valid_internals && validate_schema!(d, SDDP_SIMULATION_TASK_DEFINITION_SCHEMA, e)
    valid_keys_types =
        valid_schema && __validate_sddp_simulation_task_definition_keys_types!(d, e)

    return if valid_keys_types
        SDDPSimulationTaskDefinition(
            d["num_simulated_series"],
            d["parallel_scheme"],
            d["sampling_scheme"],
        )
    else
        nothing
    end
end

function generate_stopping_rule(s::IterationLimit)::SDDP.AbstractStoppingRule
    return SDDP.IterationLimit(s.num_iterations)
end

function generate_stopping_rule(s::TimeLimit)::SDDP.AbstractStoppingRule
    return SDDP.TimeLimit(s.time_seconds)
end

function generate_stopping_rule(s::LowerBoundStability)::SDDP.AbstractStoppingRule
    return SDDP.BoundStalling(s.num_iterations, s.threshold)
end

function generate_stopping_rule(s::Statistical)::SDDP.AbstractStoppingRule
    return SDDP.Statistical(;
        num_replications = s.num_replications,
        iteration_period = s.iteration_period,
        z_score = s.z_score,
        disable_warning = true,
    )
end

function generate_stopping_rule(s::SimulationStopping)::SDDP.AbstractStoppingRule
    return SDDP.SimulationStoppingRule(;
        replications = s.replications, period = s.period
    )
end

function generate_stopping_rule(s::FirstStageStopping)::SDDP.AbstractStoppingRule
    return SDDP.FirstStageStoppingRule(; atol = s.atol, iterations = s.iterations)
end

function generate_stopping_rule(s::StoppingChain)::SDDP.AbstractStoppingRule
    inner_rules = [generate_stopping_rule(r) for r in s.rules]
    return SDDP.StoppingChain(inner_rules...)
end

function generate_parallel_scheme(::Serial)::SDDP.AbstractParallelScheme
    return SDDP.Serial()
end

function generate_parallel_scheme(::Asynchronous)::SDDP.AbstractParallelScheme
    if Distributed.nprocs() == 1
        @warn(
            "Asynchronous parallel scheme requested but no distributed workers " *
            "are available. Use 'julia -p N' or 'Distributed.addprocs(N)' to " *
            "add workers. Running on the master process only.",
        )
    end
    return SDDP.Asynchronous()
end

function generate_parallel_scheme(::Threaded)::SDDP.AbstractParallelScheme
    if Threads.nthreads() == 1
        @warn "Threaded parallel scheme requested but Julia was started with only 1 thread. Use 'julia --threads N' for parallelism."
    end
    return SDDP.Threaded()
end

function generate_risk_measure(::Expectation)::SDDP.AbstractRiskMeasure
    return SDDP.Expectation()
end

function generate_risk_measure(::WorstCase)::SDDP.AbstractRiskMeasure
    return SDDP.WorstCase()
end

function generate_risk_measure(r::AVaR)::SDDP.AbstractRiskMeasure
    return SDDP.AVaR(r.alpha)
end

function generate_risk_measure(r::CVaR)::SDDP.AbstractRiskMeasure
    return SDDP.EAVaR(; beta = r.alpha, lambda = (1 - r.lambda))
end

function generate_risk_measure(r::Entropic)::SDDP.AbstractRiskMeasure
    return SDDP.Entropic(r.theta)
end

function generate_risk_measure(r::WassersteinRM)::SDDP.AbstractRiskMeasure
    optimizer = _find_available_optimizer()
    return SDDP.Wasserstein(x -> sum(abs, x), optimizer; alpha = r.alpha)
end

function _find_available_optimizer()
    for mod_name in (:HiGHS, :GLPK)
        try
            mod = Base.require(Main, mod_name)
            return mod.Optimizer
        catch
        end
    end
    return error(
        "WassersteinRM risk measure requires an LP solver but none could be found. " *
        "Install one: `import Pkg; Pkg.add(\"HiGHS\")`",
    )
end

function generate_risk_measure(r::ModifiedChiSquared)::SDDP.AbstractRiskMeasure
    return SDDP.ModifiedChiSquared(r.radius; minimum_std = r.minimum_std)
end

function generate_risk_measure(r::ConvexCombination)::SDDP.AbstractRiskMeasure
    sddp_measures = Tuple{Float64,SDDP.AbstractRiskMeasure}[
        (Float64(w), generate_risk_measure(rm)) for (w, rm) in r.measures
    ]
    return SDDP.ConvexCombination(sddp_measures...)
end

function generate_sampling_scheme(::DefaultSampling)::SDDP.AbstractSamplingScheme
    return SDDP.InSampleMonteCarlo()
end

function generate_sampling_scheme(
    ::DefaultSampling, graph_size::Integer
)::SDDP.AbstractSamplingScheme
    return SDDP.InSampleMonteCarlo(;
        max_depth = graph_size, terminate_on_dummy_leaf = false
    )
end

function generate_sampling_scheme(s::InSampleMC)::SDDP.AbstractSamplingScheme
    return SDDP.InSampleMonteCarlo(;
        max_depth = s.max_depth, terminate_on_dummy_leaf = s.terminate_on_dummy_leaf
    )
end

function generate_sampling_scheme(
    s::InSampleMC, ::Integer
)::SDDP.AbstractSamplingScheme
    return generate_sampling_scheme(s)
end

function generate_sampling_scheme(s::PSRSampling)::SDDP.AbstractSamplingScheme
    return SDDP.PSRSamplingScheme(s.num_samples)
end

function generate_sampling_scheme(
    s::PSRSampling, ::Integer
)::SDDP.AbstractSamplingScheme
    return generate_sampling_scheme(s)
end

function generate_duality_handler(
    ::ContinuousConicDualityHandler
)::SDDP.AbstractDualityHandler
    return SDDP.ContinuousConicDuality()
end

function generate_duality_handler(
    ::StrengthenedConicDualityHandler
)::SDDP.AbstractDualityHandler
    return SDDP.StrengthenedConicDuality()
end

function generate_duality_handler(
    ::LagrangianDualityHandler
)::SDDP.AbstractDualityHandler
    return SDDP.LagrangianDuality()
end

function generate_duality_handler(
    h::BanditDualityHandler
)::SDDP.AbstractDualityHandler
    inner = [generate_duality_handler(ih) for ih in h.handlers]
    return SDDP.BanditDuality(inner...)
end

function generate_forward_pass(::DefaultForwardPassStrategy)::SDDP.AbstractForwardPass
    return SDDP.DefaultForwardPass()
end

function generate_forward_pass(f::RevisitingForwardPassStrategy)::SDDP.AbstractForwardPass
    return SDDP.RevisitingForwardPass(f.period)
end

function generate_forward_pass(
    ::RiskAdjustedForwardPassStrategy
)::SDDP.AbstractForwardPass
    return SDDP.RiskAdjustedForwardPass(;
        forward_pass = SDDP.DefaultForwardPass(),
        risk_measure = SDDP.AVaR(0.5),
        resampling_probability = 0.5,
    )
end

function generate_forward_pass(
    f::RegularizedForwardPassStrategy
)::SDDP.AbstractForwardPass
    return SDDP.RegularizedForwardPass(; rho = f.rho)
end

function generate_cut_type(::SingleCut)::SDDP.CutType
    return SDDP.SINGLE_CUT
end

function generate_cut_type(::MultiCut)::SDDP.CutType
    return SDDP.MULTI_CUT
end

function __build_stopping_criteria!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_stopping_criteria_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    sc = d["stopping_criteria"]
    if sc isa Dict{String,Any}
        result = __kind_factory!(@__MODULE__, d, "stopping_criteria", e)
        if result && d["stopping_criteria"] !== nothing
            d["stopping_criteria"] =
                StoppingCriteria[d["stopping_criteria"]::StoppingCriteria]
        end
        return result
    elseif sc isa Vector{Dict{String,Any}}
        built = StoppingCriteria[]
        all_valid = true
        for (i, item_d) in enumerate(sc)
            obj = __single_object_factory(@__MODULE__, item_d, e)
            if obj === nothing
                all_valid = false
                continue
            end
            if !(obj isa StoppingCriteria)
                push!(
                    e,
                    AssertionError(
                        "stopping_criteria[$i] kind ($(typeof(obj))) is not a StoppingCriteria",
                    ),
                )
                all_valid = false
                continue
            end
            push!(built, obj)
        end
        if all_valid
            d["stopping_criteria"] = built
        end
        return all_valid
    else
        push!(
            e,
            ErrorException(
                "stopping_criteria must be a Dict or Vector{Dict}, got $(typeof(sc))",
            ),
        )
        return false
    end
end

function __build_stopping_chain_internals!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    raw_rules = d["rules"]
    built_rules = StoppingCriteria[]
    all_valid = true

    for (i, entry) in enumerate(raw_rules)
        if !(entry isa Dict)
            push!(e, ErrorException("StoppingChain rules[$i] must be a Dict"))
            all_valid = false
            continue
        end
        entry_d = convert(Dict{String,Any}, entry)

        obj = __single_object_factory(@__MODULE__, entry_d, e)
        if obj === nothing
            all_valid = false
            continue
        end

        if !(obj isa StoppingCriteria)
            push!(
                e,
                AssertionError(
                    "StoppingChain rules[$i] kind ($(typeof(obj))) is not a StoppingCriteria",
                ),
            )
            all_valid = false
            continue
        end

        push!(built_rules, obj)
    end

    if all_valid
        d["rules"] = built_rules
    end
    return all_valid
end

function __build_convergence!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_convergence_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    convergence_d = d["convergence"]

    valid_key_types = __validate_convergence_keys_types_before_build!(convergence_d, e)
    if !valid_key_types
        return false
    end

    d["convergence"] = Convergence(convergence_d, e)
    return d["convergence"] !== nothing
end

function __build_parallel_scheme!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_parallel_scheme_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "parallel_scheme", e)
end

function __build_risk_measure!(d::Dict{String,Any}, e::CompositeException)::Bool
    valid_key_types = __validate_risk_measure_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "risk_measure", e)
end

function __build_sampling_scheme!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "sampling_scheme")
        d["sampling_scheme"] = DefaultSampling()
        return true
    end

    valid_key_types = __validate_sampling_scheme_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "sampling_scheme", e)
end

function __build_duality_handler!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "duality_handler")
        d["duality_handler"] = DefaultDuality()
        return true
    end

    valid_key_types = __validate_duality_handler_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "duality_handler", e)
end

function __build_forward_pass!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "forward_pass")
        d["forward_pass"] = DefaultForwardPassStrategy()
        return true
    end

    valid_key_types = __validate_forward_pass_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "forward_pass", e)
end

function __build_cut_type!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "cut_type")
        d["cut_type"] = SingleCut()
        return true
    end

    valid_key_types = __validate_cut_type_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "cut_type", e)
end

function __build_scaling!(d::Dict{String,Any}, e::CompositeException)::Bool
    if !haskey(d, "scaling")
        d["scaling"] = NoScaling()
        return true
    end

    valid_key_types = __validate_scaling_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    return __kind_factory!(@__MODULE__, d, "scaling", e)
end

function __build_bandit_duality_internals!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    raw_handlers = d["handlers"]
    built_handlers = DualityHandler[]
    all_valid = true

    for (i, entry) in enumerate(raw_handlers)
        if !(entry isa Dict)
            push!(e, ErrorException("BanditDualityHandler handlers[$i] must be a Dict"))
            all_valid = false
            continue
        end
        entry_d = convert(Dict{String,Any}, entry)

        obj = __single_object_factory(@__MODULE__, entry_d, e)
        if obj === nothing
            all_valid = false
            continue
        end

        if !(obj isa DualityHandler)
            push!(
                e,
                AssertionError(
                    "BanditDualityHandler handlers[$i] kind ($(typeof(obj))) is not a DualityHandler",
                ),
            )
            all_valid = false
            continue
        end

        push!(built_handlers, obj)
    end

    if all_valid
        d["handlers"] = built_handlers
    end
    return all_valid
end

function __build_convex_combination_internals!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    raw_measures = d["measures"]
    built_measures = Tuple{Real,RiskMeasure}[]
    all_valid = true

    for (i, entry) in enumerate(raw_measures)
        if !(entry isa Dict)
            push!(e, ErrorException("ConvexCombination measures[$i] must be a Dict"))
            all_valid = false
            continue
        end
        entry_d = convert(Dict{String,Any}, entry)

        valid_weight = __validate_keys!(entry_d, ["weight"], e)
        if !valid_weight
            all_valid = false
            continue
        end
        weight = entry_d["weight"]
        if !(weight isa Real)
            push!(e, ErrorException("Key 'weight' ($weight) can't be converted to Real"))
            all_valid = false
            continue
        end
        weight = convert(Float64, weight)
        if weight <= 0.0 || weight > 1.0
            push!(
                e,
                AssertionError(
                    "ConvexCombination measures[$i] weight ($weight) must be in (0, 1]",
                ),
            )
            all_valid = false
            continue
        end

        valid_rm_key = __validate_keys!(entry_d, ["risk_measure"], e)
        if !valid_rm_key
            all_valid = false
            continue
        end
        rm_d = entry_d["risk_measure"]
        if !(rm_d isa Dict)
            push!(e, ErrorException("Key 'risk_measure' must be a Dict"))
            all_valid = false
            continue
        end
        rm_dict = convert(Dict{String,Any}, rm_d)

        valid_kind_params = __validate_kind_params_keys!(rm_dict, e)
        if !valid_kind_params
            all_valid = false
            continue
        end

        kind = rm_dict["kind"]
        params = rm_dict["params"]

        kind_type = nothing
        try
            kind_type = getfield(@__MODULE__, Symbol(kind))
        catch
            push!(e, AssertionError("Kind ($kind) not recognized"))
            all_valid = false
            continue
        end

        rm_obj = kind_type(convert(Dict{String,Any}, params), e)
        if rm_obj === nothing
            all_valid = false
            continue
        end

        if !(rm_obj isa RiskMeasure)
            push!(
                e,
                AssertionError(
                    "ConvexCombination measures[$i] risk_measure kind ($kind) is not a RiskMeasure",
                ),
            )
            all_valid = false
            continue
        end

        push!(built_measures, (weight, rm_obj))
    end

    if all_valid
        d["measures"] = built_measures
    end
    return all_valid
end

function __build_sddp_policy_task_definition!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_sddp_policy_task_definition_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    policy_d = d["policy"]

    valid_key_types = __validate_sddp_policy_task_definition_keys_types_before_build!(
        policy_d, e
    )
    if !valid_key_types
        return false
    end

    d["policy"] = SDDPPolicyTaskDefinition(policy_d, e)
    return d["policy"] !== nothing
end

function __build_sddp_simulation_task_definition!(
    d::Dict{String,Any}, e::CompositeException
)::Bool
    valid_key_types = __validate_sddp_simulation_task_definition_main_key_type!(d, e)
    if !valid_key_types
        return false
    end

    simulation_d = d["simulation"]

    valid_key_types = __validate_sddp_simulation_task_definition_keys_types_before_build!(
        simulation_d, e
    )
    if !valid_key_types
        return false
    end

    d["simulation"] = SDDPSimulationTaskDefinition(simulation_d, e)
    return d["simulation"] !== nothing
end
