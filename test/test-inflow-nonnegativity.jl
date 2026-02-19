using SDDPlab: SDDPlab
import SDDPlab: Engines, Lab, Scenarios, Inputs, StochasticProcess
using SDDP: SDDP
using JuMP: JuMP
using HiGHS: HiGHS
using Suppressor
import Distributions
import Copulas

@testset "inflow-nonnegativity" begin
    # =======================================================================
    # Config parsing tests
    # =======================================================================
    @testset "config-parsing" begin
        # Helper: minimal SDDPEngine dict (policy + simulation)
        function _base_engine_dict()
            policy_dict = Dict{String,Any}(
                "convergence" => Dict{String,Any}(
                    "min_iterations" => 1,
                    "max_iterations" => 3,
                    "stopping_criteria" => Dict{String,Any}(
                        "kind" => "IterationLimit",
                        "params" => Dict{String,Any}("num_iterations" => 3),
                    ),
                ),
                "risk_measure" => Dict{String,Any}(
                    "kind" => "Expectation", "params" => Dict{String,Any}()
                ),
                "parallel_scheme" => Dict{String,Any}(
                    "kind" => "Serial", "params" => Dict{String,Any}()
                ),
            )
            simulation_dict = Dict{String,Any}(
                "num_simulated_series" => 10,
                "parallel_scheme" => Dict{String,Any}(
                    "kind" => "Serial", "params" => Dict{String,Any}()
                ),
            )
            return Dict{String,Any}(
                "policy" => policy_dict,
                "simulation" => simulation_dict,
            )
        end

        @testset "default-inflownone-when-no-modeling-key" begin
            params = _base_engine_dict()
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.inflow_non_negativity isa Engines.InflowNone
        end

        @testset "inflownone-from-modeling-dict" begin
            params = _base_engine_dict()
            params["modeling"] = Dict{String,Any}(
                "inflow_non_negativity" => Dict{String,Any}(
                    "kind" => "InflowNone",
                    "params" => Dict{String,Any}(),
                ),
            )
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.inflow_non_negativity isa Engines.InflowNone
        end

        @testset "inflowpenalty-from-modeling-dict" begin
            params = _base_engine_dict()
            params["modeling"] = Dict{String,Any}(
                "inflow_non_negativity" => Dict{String,Any}(
                    "kind" => "InflowPenalty",
                    "params" => Dict{String,Any}("penalty_cost" => 1000.0),
                ),
            )
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.inflow_non_negativity isa Engines.InflowPenalty
            @test result.inflow_non_negativity.penalty_cost == 1000.0
        end

        @testset "inflowtruncation-from-modeling-dict" begin
            params = _base_engine_dict()
            params["modeling"] = Dict{String,Any}(
                "inflow_non_negativity" => Dict{String,Any}(
                    "kind" => "InflowTruncation",
                    "params" => Dict{String,Any}(),
                ),
            )
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.inflow_non_negativity isa Engines.InflowTruncation
        end

        @testset "inflowtruncationwithpenalty-from-modeling-dict" begin
            params = _base_engine_dict()
            params["modeling"] = Dict{String,Any}(
                "inflow_non_negativity" => Dict{String,Any}(
                    "kind" => "InflowTruncationWithPenalty",
                    "params" => Dict{String,Any}("penalty_cost" => 500.0),
                ),
            )
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result !== nothing
            @test length(e) == 0
            @test result.inflow_non_negativity isa Engines.InflowTruncationWithPenalty
            @test result.inflow_non_negativity.penalty_cost == 500.0
        end

        @testset "negative-penalty-cost-error" begin
            params = _base_engine_dict()
            params["modeling"] = Dict{String,Any}(
                "inflow_non_negativity" => Dict{String,Any}(
                    "kind" => "InflowPenalty",
                    "params" => Dict{String,Any}("penalty_cost" => -100.0),
                ),
            )
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "zero-penalty-cost-error" begin
            params = _base_engine_dict()
            params["modeling"] = Dict{String,Any}(
                "inflow_non_negativity" => Dict{String,Any}(
                    "kind" => "InflowPenalty",
                    "params" => Dict{String,Any}("penalty_cost" => 0.0),
                ),
            )
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result === nothing
            @test length(e) > 0
        end

        @testset "invalid-kind-error" begin
            params = _base_engine_dict()
            params["modeling"] = Dict{String,Any}(
                "inflow_non_negativity" => Dict{String,Any}(
                    "kind" => "NonExistentMethod",
                    "params" => Dict{String,Any}(),
                ),
            )
            e = CompositeException()
            result = Engines.SDDPEngine(params, e)
            @test result === nothing
            @test length(e) > 0
        end
    end

    # =======================================================================
    # Direct struct construction
    # =======================================================================
    @testset "direct-struct-construction" begin
        @testset "inflownone-5th-field" begin
            convergence = Engines.Convergence(1, 3, [Engines.IterationLimit(3)])
            policy = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy,
                sim,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
            )
            @test engine.inflow_non_negativity isa Engines.InflowNone
        end

        @testset "inflowpenalty-5th-field" begin
            convergence = Engines.Convergence(1, 3, [Engines.IterationLimit(3)])
            policy = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim = Engines.SDDPSimulationTaskDefinition(
                10, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy,
                sim,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowPenalty(1000.0),
            )
            @test engine.inflow_non_negativity isa Engines.InflowPenalty
            @test engine.inflow_non_negativity.penalty_cost == 1000.0
        end
    end

    # =======================================================================
    # E2E backward compatibility: 1dtoy with InflowNone (Naive process)
    # =======================================================================
    @testset "e2e-1dtoy-inflownone-backward-compat" begin
        e = CompositeException()
        @suppress begin
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 5, [Engines.IterationLimit(5)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                5, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowNone(),
            )
            study = SDDPlab.Study(original.inputs, engine)

            model = SDDPlab.build(study, HiGHS.Optimizer)
            @test model !== nothing

            # InflowNone should NOT have INFLOW_SLACK or NOISE_ADJUSTMENT_SLACK
            sp = model.policy_graph[2].subproblem
            @test !haskey(JuMP.object_dictionary(sp), Lab.INFLOW_SLACK)
            @test !haskey(JuMP.object_dictionary(sp), Lab.NOISE_ADJUSTMENT_SLACK)

            policy = SDDPlab.train(study, model)
            @test policy !== nothing

            simulation = SDDPlab.simulate(study, model)
            @test simulation !== nothing
        end
    end

    # =======================================================================
    # Naive process with non-None method: warning + fallback
    # =======================================================================
    @testset "naive-process-penalty-warning" begin
        e = CompositeException()
        @suppress begin
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 3, [Engines.IterationLimit(3)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                5, Engines.Serial(), Engines.DefaultSampling()
            )
            # Use InflowPenalty with a Naive process -- should warn and still work
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowPenalty(1000.0),
            )
            study = SDDPlab.Study(original.inputs, engine)

            # Should build without error (warning logged, fallback to InflowNone behavior)
            model = SDDPlab.build(study, HiGHS.Optimizer)
            @test model !== nothing

            # No INFLOW_SLACK -- Naive fallback means no extra variables
            sp = model.policy_graph[2].subproblem
            @test !haskey(JuMP.object_dictionary(sp), Lab.INFLOW_SLACK)
        end
    end

    # =======================================================================
    # E2E with InflowTruncation: SAA noise values >= 0
    # =======================================================================
    @testset "e2e-1dtoy-inflowtruncation" begin
        e = CompositeException()
        @suppress begin
            original = SDDPlab.read_study(example_dir; e = e)
            @test length(e) == 0

            convergence = Engines.Convergence(
                1, 5, [Engines.IterationLimit(5)]
            )
            policy_def = Engines.SDDPPolicyTaskDefinition(
                convergence,
                Engines.Expectation(),
                Engines.Serial(),
                Engines.DefaultSampling(),
                Engines.DefaultDuality(),
                Engines.DefaultForwardPassStrategy(),
                Engines.SingleCut(),
                Engines.NoScaling(),
            )
            sim_def = Engines.SDDPSimulationTaskDefinition(
                5, Engines.Serial(), Engines.DefaultSampling()
            )
            engine = Engines.SDDPEngine(
                policy_def,
                sim_def,
                Engines.DiagnosticsConfig(false, 1e6, 1e10),
                Engines.SolverConfig("HiGHS", Dict{String,Any}()),
                Engines.InflowTruncation(),
            )
            study = SDDPlab.Study(original.inputs, engine)

            # Should build and train successfully (Naive process ignores truncation on LP side)
            model = SDDPlab.build(study, HiGHS.Optimizer)
            @test model !== nothing

            policy = SDDPlab.train(study, model)
            @test policy !== nothing
        end
    end

    # =======================================================================
    # LP structure tests with AR process
    # =======================================================================
    # NOTE: add_inflow_uncertainty! creates SDDP.State variables which require
    # a proper SDDP subproblem context. We use SDDP.LinearPolicyGraph as the
    # test harness and inspect the resulting subproblem model.

    # Helper: build a minimal AutoRegressive process for unit testing
    function _make_test_ar_process()
        ar_params = StochasticProcess.SimpleARparameters(
            [0.5],           # phi coefficients
            [40.0, 10.0],    # scale [mean, std]
            1,               # season
        )
        uar = StochasticProcess.UnivariateAutoRegressive(1, [40.0], ar_params)
        # Build minimal Naive noise model (required for AR struct)
        un = StochasticProcess.UnitaryNaive(
            1,
            Dict{Integer,Distributions.UnivariateDistribution}(
                1 => Distributions.Normal(0.0, 1.0),
            ),
        )
        copula = Copulas.GaussianCopula([1.0;;])
        noise = StochasticProcess.Naive(
            [un], Dict{Integer,Copulas.Copula}(1 => copula)
        )
        return StochasticProcess.AutoRegressive([uar], noise)
    end

    # Helper: build a 1-stage SDDP policy graph, call add_inflow_uncertainty!
    # inside the builder, and return the resulting subproblem model.
    function _build_lp_with_method(ar_process, method)
        captured_model = Ref{JuMP.Model}()
        n_hydro = 1

        model = SDDP.LinearPolicyGraph(;
            stages = 1,
            sense = :Min,
            lower_bound = 0.0,
            optimizer = HiGHS.Optimizer,
        ) do sp, t
            JuMP.set_silent(sp)
            sp[Lab.INFLOW] = JuMP.@variable(sp, [1:n_hydro], base_name = "INFLOW")
            Engines.add_inflow_uncertainty!(sp, ar_process, 1, method)
            SDDP.@stageobjective(sp, 0.0)
            captured_model[] = sp
        end

        return captured_model[]
    end

    @testset "lp-structure-inflowpenalty-ar" begin
        ar_process = _make_test_ar_process()
        method = Engines.InflowPenalty(1000.0)
        m = _build_lp_with_method(ar_process, method)

        # Should have INFLOW_SLACK
        @test haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)
        @test length(m[Lab.INFLOW_SLACK]) == 1

        # INFLOW_SLACK >= 0
        @test JuMP.lower_bound(m[Lab.INFLOW_SLACK][1]) == 0.0

        # INFLOW >= 0
        @test JuMP.lower_bound(m[Lab.INFLOW][1]) == 0.0

        # Should NOT have NOISE_ADJUSTMENT_SLACK
        @test !haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)
    end

    @testset "lp-structure-inflowtruncationwithpenalty-ar" begin
        ar_process = _make_test_ar_process()
        method = Engines.InflowTruncationWithPenalty(500.0)
        m = _build_lp_with_method(ar_process, method)

        # Should have NOISE_ADJUSTMENT_SLACK
        @test haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)
        @test length(m[Lab.NOISE_ADJUSTMENT_SLACK]) == 1

        # NOISE_ADJUSTMENT_SLACK >= 0
        @test JuMP.lower_bound(m[Lab.NOISE_ADJUSTMENT_SLACK][1]) == 0.0

        # INFLOW >= 0
        @test JuMP.lower_bound(m[Lab.INFLOW][1]) == 0.0

        # Should NOT have INFLOW_SLACK
        @test !haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)

        # Sigma values stored in ext
        @test haskey(m.ext, :noise_adjustment_sigma)
        @test m.ext[:noise_adjustment_sigma] == [10.0]
    end

    @testset "lp-structure-inflownone-ar" begin
        ar_process = _make_test_ar_process()
        method = Engines.InflowNone()
        m = _build_lp_with_method(ar_process, method)

        # Should NOT have INFLOW_SLACK or NOISE_ADJUSTMENT_SLACK
        @test !haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)
        @test !haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)

        # INFLOW should NOT have lower bound (default is -Inf)
        @test !JuMP.has_lower_bound(m[Lab.INFLOW][1])
    end

    @testset "lp-structure-inflowtruncation-ar" begin
        ar_process = _make_test_ar_process()
        method = Engines.InflowTruncation()
        m = _build_lp_with_method(ar_process, method)

        # InflowTruncation modifies SAA (not LP), so no extra variables
        @test !haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)
        @test !haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)

        # No lower bound on INFLOW (truncation is SAA-side only)
        @test !JuMP.has_lower_bound(m[Lab.INFLOW][1])
    end

    # =======================================================================
    # Penalty expression tests
    # =======================================================================
    @testset "penalty-expression" begin
        @testset "inflownone-returns-zero" begin
            m = JuMP.Model()
            tau_k = [744.0]
            scaling = Engines.no_scaling_config()
            penalty = Engines._inflow_penalty_expr(m, Engines.InflowNone(), tau_k, scaling)
            @test penalty == 0.0
        end

        @testset "inflowtruncation-returns-zero" begin
            m = JuMP.Model()
            tau_k = [744.0]
            scaling = Engines.no_scaling_config()
            penalty = Engines._inflow_penalty_expr(m, Engines.InflowTruncation(), tau_k, scaling)
            @test penalty == 0.0
        end

        @testset "inflowpenalty-returns-expression" begin
            m = JuMP.Model()
            n_hydro = 2
            m[Lab.INFLOW_SLACK] = JuMP.@variable(m, [1:n_hydro], base_name = "INFLOW_SLACK")
            tau_k = [744.0]
            scaling = Engines.no_scaling_config()
            method = Engines.InflowPenalty(1000.0)
            penalty = Engines._inflow_penalty_expr(m, method, tau_k, scaling)
            # With no scaling (all factors = 1.0):
            # scaled_coeff = 1000.0 * 0.0036 * 744.0 * 1.0 / (1.0 * 1.0)
            expected_coeff = 1000.0 * 0.0036 * 744.0
            @test penalty isa JuMP.GenericAffExpr
            # Check the coefficient is correct for the first variable
            @test JuMP.coefficient(penalty, m[Lab.INFLOW_SLACK][1]) == expected_coeff
        end

        @testset "inflowtruncationwithpenalty-returns-expression" begin
            m = JuMP.Model()
            n_hydro = 1
            m[Lab.NOISE_ADJUSTMENT_SLACK] = JuMP.@variable(
                m, [1:n_hydro], base_name = "NOISE_ADJUSTMENT_SLACK"
            )
            m.ext[:noise_adjustment_sigma] = [10.0]
            tau_k = [744.0]
            scaling = Engines.no_scaling_config()
            method = Engines.InflowTruncationWithPenalty(500.0)
            penalty = Engines._inflow_penalty_expr(m, method, tau_k, scaling)
            # scaled_coeff = 500.0 * 0.0036 * 744.0 * 10.0 / (1.0 * 1.0)
            expected_coeff = 500.0 * 0.0036 * 744.0 * 10.0
            @test penalty isa JuMP.GenericAffExpr
            @test JuMP.coefficient(penalty, m[Lab.NOISE_ADJUSTMENT_SLACK][1]) == expected_coeff
        end
    end
end
