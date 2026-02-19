using SDDPlab: SDDPlab
import SDDPlab: Engines, Lab, Scenarios, StochasticProcess
using SDDP: SDDP
using JuMP: JuMP
using HiGHS: HiGHS
import Distributions
import Copulas

# ===========================================================================
# Helper: build a valid 2-element VAR(1) params dict with 2 seasons
# ===========================================================================
function _var1_2elem_2season_dict()
    return Dict{String,Any}(
        "marginal_models" => [
            Dict{String,Any}(
                "id" => 1,
                "initial_values" => [100.0],
                "models" => [
                    Dict{String,Any}(
                        "season" => 1,
                        "residual_variance" => 0.04,
                        "scale_parameters" => [150.0, 20.0],
                    ),
                    Dict{String,Any}(
                        "season" => 2,
                        "residual_variance" => 0.05,
                        "scale_parameters" => [180.0, 25.0],
                    ),
                ],
            ),
            Dict{String,Any}(
                "id" => 2,
                "initial_values" => [80.0],
                "models" => [
                    Dict{String,Any}(
                        "season" => 1,
                        "residual_variance" => 0.03,
                        "scale_parameters" => [120.0, 15.0],
                    ),
                    Dict{String,Any}(
                        "season" => 2,
                        "residual_variance" => 0.04,
                        "scale_parameters" => [140.0, 20.0],
                    ),
                ],
            ),
        ],
        "copulas" => [
            Dict{String,Any}("kind" => "GaussianCopula", "parameters" => [[1.0, 0.0], [0.0, 1.0]]),
            Dict{String,Any}("kind" => "GaussianCopula", "parameters" => [[1.0, 0.0], [0.0, 1.0]]),
        ],
        "coefficient_matrices" => [
            Dict{String,Any}(
                "season" => 1,
                "lag" => 1,
                "matrix" => [[0.5, 0.1], [0.2, 0.4]],
            ),
            Dict{String,Any}(
                "season" => 2,
                "lag" => 1,
                "matrix" => [[0.6, 0.15], [0.1, 0.5]],
            ),
        ],
    )
end

# ===========================================================================
# Helper: build a valid 2-element VAR(2) params dict with 2 seasons
# ===========================================================================
function _var2_2elem_2season_dict()
    return Dict{String,Any}(
        "marginal_models" => [
            Dict{String,Any}(
                "id" => 1,
                "initial_values" => [100.0, 110.0],
                "models" => [
                    Dict{String,Any}(
                        "season" => 1,
                        "residual_variance" => 0.04,
                        "scale_parameters" => [150.0, 20.0],
                    ),
                    Dict{String,Any}(
                        "season" => 2,
                        "residual_variance" => 0.05,
                        "scale_parameters" => [180.0, 25.0],
                    ),
                ],
            ),
            Dict{String,Any}(
                "id" => 2,
                "initial_values" => [80.0, 90.0],
                "models" => [
                    Dict{String,Any}(
                        "season" => 1,
                        "residual_variance" => 0.03,
                        "scale_parameters" => [120.0, 15.0],
                    ),
                    Dict{String,Any}(
                        "season" => 2,
                        "residual_variance" => 0.04,
                        "scale_parameters" => [140.0, 20.0],
                    ),
                ],
            ),
        ],
        "copulas" => [
            Dict{String,Any}("kind" => "GaussianCopula", "parameters" => [[1.0, 0.0], [0.0, 1.0]]),
            Dict{String,Any}("kind" => "GaussianCopula", "parameters" => [[1.0, 0.0], [0.0, 1.0]]),
        ],
        "coefficient_matrices" => [
            Dict{String,Any}(
                "season" => 1,
                "lag" => 1,
                "matrix" => [[0.5, 0.1], [0.2, 0.4]],
            ),
            Dict{String,Any}(
                "season" => 1,
                "lag" => 2,
                "matrix" => [[0.1, 0.0], [0.0, 0.1]],
            ),
            Dict{String,Any}(
                "season" => 2,
                "lag" => 1,
                "matrix" => [[0.6, 0.15], [0.1, 0.5]],
            ),
            Dict{String,Any}(
                "season" => 2,
                "lag" => 2,
                "matrix" => [[0.05, 0.0], [0.0, 0.05]],
            ),
        ],
    )
end

# ===========================================================================
# Helper: build a 1-element VAR(1) for simple tests
# ===========================================================================
function _var1_1elem_1season_dict()
    return Dict{String,Any}(
        "marginal_models" => [
            Dict{String,Any}(
                "id" => 1,
                "initial_values" => [40.0],
                "models" => [
                    Dict{String,Any}(
                        "season" => 1,
                        "residual_variance" => 1.0,
                        "scale_parameters" => [40.0, 10.0],
                    ),
                ],
            ),
        ],
        "copulas" => [
            Dict{String,Any}("kind" => "GaussianCopula", "parameters" => [[1.0]]),
        ],
        "coefficient_matrices" => [
            Dict{String,Any}(
                "season" => 1,
                "lag" => 1,
                "matrix" => [[0.5]],
            ),
        ],
    )
end

# ===========================================================================
# Helper: build LP model for testing add_inflow_uncertainty!
# ===========================================================================
function _build_var_lp_with_method(var_process, method; n_hydro = nothing)
    if isnothing(n_hydro)
        n_hydro = length(var_process)
    end
    captured_model = Ref{JuMP.Model}()

    model = SDDP.LinearPolicyGraph(;
        stages = 1,
        sense = :Min,
        lower_bound = 0.0,
        optimizer = HiGHS.Optimizer,
    ) do sp, t
        JuMP.set_silent(sp)
        sp[Lab.INFLOW] = JuMP.@variable(sp, [1:n_hydro], base_name = "INFLOW")
        Engines.add_inflow_uncertainty!(sp, var_process, 1, method)
        SDDP.@stageobjective(sp, 0.0)
        captured_model[] = sp
    end

    return captured_model[]
end

@testset "vectorautoregressive" begin

    # ===================================================================
    # Constructor tests
    # ===================================================================
    @testset "constructor" begin
        @testset "valid-var1-2elem-2season" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var !== nothing
            @test length(e) == 0
            @test var isa StochasticProcess.VectorAutoRegressive
            @test var.max_lag == 1
            @test var.num_seasons == 2
            @test length(var) == 2
        end

        @testset "valid-var2-2elem-2season" begin
            d = _var2_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var !== nothing
            @test length(e) == 0
            @test var.max_lag == 2
            @test var.num_seasons == 2
            @test length(var) == 2
        end

        @testset "valid-var1-1elem-1season" begin
            d = _var1_1elem_1season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var !== nothing
            @test length(e) == 0
            @test var.max_lag == 1
            @test var.num_seasons == 1
            @test length(var) == 1
        end

        @testset "missing-coefficient-matrices" begin
            d = _var1_2elem_2season_dict()
            delete!(d, "coefficient_matrices")
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "missing-marginal-models" begin
            d = _var1_2elem_2season_dict()
            delete!(d, "marginal_models")
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "missing-copulas" begin
            d = _var1_2elem_2season_dict()
            delete!(d, "copulas")
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "wrong-matrix-dimensions-rows" begin
            d = _var1_2elem_2season_dict()
            # Change matrix to 3x2 (wrong number of rows)
            d["coefficient_matrices"][1]["matrix"] = [[0.5, 0.1], [0.2, 0.4], [0.1, 0.1]]
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "wrong-matrix-dimensions-cols" begin
            d = _var1_2elem_2season_dict()
            # Change matrix to 2x3 (wrong number of columns)
            d["coefficient_matrices"][1]["matrix"] = [[0.5, 0.1, 0.0], [0.2, 0.4, 0.0]]
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "negative-residual-variance" begin
            d = _var1_1elem_1season_dict()
            d["marginal_models"][1]["models"][1]["residual_variance"] = -0.04
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "negative-season" begin
            d = _var1_1elem_1season_dict()
            d["coefficient_matrices"][1]["season"] = -1
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "negative-lag" begin
            d = _var1_1elem_1season_dict()
            d["coefficient_matrices"][1]["lag"] = -1
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "mismatched-initial-values-length" begin
            d = _var2_2elem_2season_dict()
            # VAR(2) requires 2 initial values per element
            d["marginal_models"][1]["initial_values"] = [100.0]  # only 1, should be 2
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "negative-id" begin
            d = _var1_1elem_1season_dict()
            d["marginal_models"][1]["id"] = -1
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end

        @testset "negative-std-in-scale" begin
            d = _var1_1elem_1season_dict()
            d["marginal_models"][1]["models"][1]["scale_parameters"] = [40.0, -10.0]
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test var === nothing
            @test length(e) > 0
        end
    end

    # ===================================================================
    # Size and length tests
    # ===================================================================
    @testset "size-length" begin
        @testset "length-returns-num-elements" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test length(var) == 2
        end

        @testset "size-returns-correct-tuple-var1" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            s = size(var)
            @test s == (2, 2, 1)  # (N, num_seasons, max_lag)
        end

        @testset "size-returns-correct-tuple-var2" begin
            d = _var2_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            s = size(var)
            @test s == (2, 2, 2)  # (N, num_seasons, max_lag)
        end

        @testset "size-indexed-access" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            @test size(var, 1) == 2  # N
            @test size(var, 2) == 2  # num_seasons
            @test size(var, 3) == 1  # max_lag
        end
    end

    # ===================================================================
    # Accessor tests
    # ===================================================================
    @testset "accessors" begin
        @testset "get-var-scales" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            scales_s1 = StochasticProcess.get_var_scales(var, 1)
            @test scales_s1[1] == [150.0, 20.0]
            @test scales_s1[2] == [120.0, 15.0]
            scales_s2 = StochasticProcess.get_var_scales(var, 2)
            @test scales_s2[1] == [180.0, 25.0]
            @test scales_s2[2] == [140.0, 20.0]
        end

        @testset "get-var-coefficient-matrix" begin
            d = _var2_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            phi_s1_l1 = StochasticProcess.get_var_coefficient_matrix(var, 1, 1)
            @test phi_s1_l1 == [0.5 0.1; 0.2 0.4]
            phi_s1_l2 = StochasticProcess.get_var_coefficient_matrix(var, 1, 2)
            @test phi_s1_l2 == [0.1 0.0; 0.0 0.1]
        end

        @testset "get-ids" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            ids = StochasticProcess.__get_ids(var)
            @test ids == [1, 2]
        end
    end

    # ===================================================================
    # SAA generation tests
    # ===================================================================
    @testset "saa-generation" begin
        @testset "correct-dimensions" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            saa = StochasticProcess.generate_saa(var, 1, 4, 3, 42)
            # dimensions: [num_stages][num_branchings][num_elements]
            @test length(saa) == 4       # N stages
            @test length(saa[1]) == 3    # B branchings
            @test length(saa[1][1]) == 2 # 2 elements
        end

        @testset "reproducible-with-seed" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            saa1 = StochasticProcess.generate_saa(var, 1, 4, 3, 42)
            saa2 = StochasticProcess.generate_saa(var, 1, 4, 3, 42)
            @test saa1 == saa2
        end

        @testset "different-with-different-seed" begin
            d = _var1_2elem_2season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            saa1 = StochasticProcess.generate_saa(var, 1, 4, 3, 42)
            saa2 = StochasticProcess.generate_saa(var, 1, 4, 3, 99)
            @test saa1 != saa2
        end

        @testset "1-element-correct-dimensions" begin
            d = _var1_1elem_1season_dict()
            e = CompositeException()
            var = StochasticProcess.VectorAutoRegressive(d, e)
            saa = StochasticProcess.generate_saa(var, 1, 5, 10, 42)
            @test length(saa) == 5        # N stages
            @test length(saa[1]) == 10    # B branchings
            @test length(saa[1][1]) == 1  # 1 element
        end
    end

    # ===================================================================
    # LP structure tests - VAR(1) 2 elements - InflowNone
    # ===================================================================
    @testset "lp-structure-var1-inflownone" begin
        d = _var1_2elem_2season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)
        @test var !== nothing

        m = _build_var_lp_with_method(var, Engines.InflowNone())

        # STCHP: 2 elements x 1 lag = 2 state variables
        @test haskey(JuMP.object_dictionary(m), Lab.STCHP)
        @test length(m[Lab.STCHP]) == 2

        # omega_INFLOW: 2 noise variables
        @test haskey(JuMP.object_dictionary(m), Lab.ω_INFLOW)
        @test length(m[Lab.ω_INFLOW]) == 2

        # INFLOW: 2 variables
        @test haskey(JuMP.object_dictionary(m), Lab.INFLOW)
        @test length(m[Lab.INFLOW]) == 2

        # No INFLOW_SLACK or NOISE_ADJUSTMENT_SLACK
        @test !haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)
        @test !haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)

        # INFLOW should not have lower bound
        @test !JuMP.has_lower_bound(m[Lab.INFLOW][1])
        @test !JuMP.has_lower_bound(m[Lab.INFLOW][2])
    end

    # ===================================================================
    # LP structure tests - VAR(2) 2 elements - InflowNone
    # ===================================================================
    @testset "lp-structure-var2-inflownone" begin
        d = _var2_2elem_2season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)
        @test var !== nothing

        m = _build_var_lp_with_method(var, Engines.InflowNone())

        # STCHP: 2 elements x 2 lags = 4 state variables
        @test haskey(JuMP.object_dictionary(m), Lab.STCHP)
        @test length(m[Lab.STCHP]) == 4

        # omega_INFLOW: 2 noise variables
        @test length(m[Lab.ω_INFLOW]) == 2

        # INFLOW: 2 variables
        @test length(m[Lab.INFLOW]) == 2

        # No INFLOW_SLACK or NOISE_ADJUSTMENT_SLACK
        @test !haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)
        @test !haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)
    end

    # ===================================================================
    # LP structure tests - VAR(1) 2 elements - InflowPenalty
    # ===================================================================
    @testset "lp-structure-var1-inflowpenalty" begin
        d = _var1_2elem_2season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)

        m = _build_var_lp_with_method(var, Engines.InflowPenalty(1000.0))

        # Should have INFLOW_SLACK
        @test haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)
        @test length(m[Lab.INFLOW_SLACK]) == 2

        # INFLOW_SLACK >= 0
        @test JuMP.lower_bound(m[Lab.INFLOW_SLACK][1]) == 0.0
        @test JuMP.lower_bound(m[Lab.INFLOW_SLACK][2]) == 0.0

        # INFLOW >= 0
        @test JuMP.lower_bound(m[Lab.INFLOW][1]) == 0.0
        @test JuMP.lower_bound(m[Lab.INFLOW][2]) == 0.0

        # No NOISE_ADJUSTMENT_SLACK
        @test !haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)
    end

    # ===================================================================
    # LP structure tests - VAR(1) 2 elements - InflowTruncation
    # ===================================================================
    @testset "lp-structure-var1-inflowtruncation" begin
        d = _var1_2elem_2season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)

        m = _build_var_lp_with_method(var, Engines.InflowTruncation())

        # No extra variables
        @test !haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)
        @test !haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)

        # No lower bound on INFLOW (truncation is SAA-side only)
        @test !JuMP.has_lower_bound(m[Lab.INFLOW][1])
        @test !JuMP.has_lower_bound(m[Lab.INFLOW][2])
    end

    # ===================================================================
    # LP structure tests - VAR(1) 2 elements - InflowTruncationWithPenalty
    # ===================================================================
    @testset "lp-structure-var1-inflowtruncationwithpenalty" begin
        d = _var1_2elem_2season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)

        m = _build_var_lp_with_method(var, Engines.InflowTruncationWithPenalty(500.0))

        # Should have NOISE_ADJUSTMENT_SLACK
        @test haskey(JuMP.object_dictionary(m), Lab.NOISE_ADJUSTMENT_SLACK)
        @test length(m[Lab.NOISE_ADJUSTMENT_SLACK]) == 2

        # NOISE_ADJUSTMENT_SLACK >= 0
        @test JuMP.lower_bound(m[Lab.NOISE_ADJUSTMENT_SLACK][1]) == 0.0
        @test JuMP.lower_bound(m[Lab.NOISE_ADJUSTMENT_SLACK][2]) == 0.0

        # INFLOW >= 0
        @test JuMP.lower_bound(m[Lab.INFLOW][1]) == 0.0
        @test JuMP.lower_bound(m[Lab.INFLOW][2]) == 0.0

        # No INFLOW_SLACK
        @test !haskey(JuMP.object_dictionary(m), Lab.INFLOW_SLACK)

        # Sigma values stored in ext
        @test haskey(m.ext, :noise_adjustment_sigma)
        @test m.ext[:noise_adjustment_sigma] == [20.0, 15.0]
    end

    # ===================================================================
    # LP structure test - VAR(1) 1 element degeneracy (diagonal case)
    # ===================================================================
    @testset "lp-structure-var1-1elem-inflownone" begin
        d = _var1_1elem_1season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)

        m = _build_var_lp_with_method(var, Engines.InflowNone(); n_hydro = 1)

        # STCHP: 1 element x 1 lag = 1 state variable
        @test length(m[Lab.STCHP]) == 1
        @test length(m[Lab.ω_INFLOW]) == 1
        @test length(m[Lab.INFLOW]) == 1
    end

    # ===================================================================
    # LP structure test - verify memory shift constraints for VAR(2)
    # ===================================================================
    @testset "lp-structure-var2-memory-shift" begin
        d = _var2_2elem_2season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)

        m = _build_var_lp_with_method(var, Engines.InflowNone())

        # VAR(2) with 2 elements: STCHP has 4 states
        # index_t = [1, 3] (current values)
        # memory_states = [2, 4] (lagged values shifted from .in)
        @test length(m[Lab.STCHP]) == 4

        # Verify memory shift constraints exist by checking
        # the model has the var_memory constraints
        @test haskey(JuMP.object_dictionary(m), :var_memory)
    end

    # ===================================================================
    # kind_factory resolution test (JSONC integration)
    # ===================================================================
    @testset "kind-factory-resolution" begin
        d = Dict{String,Any}(
            "stochastic_process" => Dict{String,Any}(
                "kind" => "VectorAutoRegressive",
                "params" => _var1_2elem_2season_dict(),
            ),
        )
        e = CompositeException()
        inflow = Scenarios.InflowScenarios(d, e)
        @test inflow !== nothing
        @test length(e) == 0
        @test Scenarios.get_stochastic_process(inflow) isa StochasticProcess.VectorAutoRegressive
    end

    # ===================================================================
    # Backward compatibility: AutoRegressive still works
    # ===================================================================
    @testset "backward-compat-autoregressive" begin
        ar_params = StochasticProcess.SimpleARparameters(
            [0.5],           # phi coefficients
            [40.0, 10.0],    # scale [mean, std]
            1,               # season
        )
        uar = StochasticProcess.UnivariateAutoRegressive(1, [40.0], ar_params)
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
        ar = StochasticProcess.AutoRegressive([uar], noise)

        # SAA generation still works
        saa = StochasticProcess.generate_saa(ar, 1, 3, 2, 42)
        @test length(saa) == 3
        @test length(saa[1]) == 2
        @test length(saa[1][1]) == 1

        # LP structure still works
        captured_model = Ref{JuMP.Model}()
        model = SDDP.LinearPolicyGraph(;
            stages = 1,
            sense = :Min,
            lower_bound = 0.0,
            optimizer = HiGHS.Optimizer,
        ) do sp, t
            JuMP.set_silent(sp)
            sp[Lab.INFLOW] = JuMP.@variable(sp, [1:1], base_name = "INFLOW")
            Engines.add_inflow_uncertainty!(sp, ar, 1, Engines.InflowNone())
            SDDP.@stageobjective(sp, 0.0)
            captured_model[] = sp
        end
        m = captured_model[]
        @test haskey(JuMP.object_dictionary(m), Lab.STCHP)
        @test length(m[Lab.STCHP]) == 1
    end

    # ===================================================================
    # Coefficient matrix parsing correctness
    # ===================================================================
    @testset "coefficient-matrix-parsing" begin
        d = _var2_2elem_2season_dict()
        e = CompositeException()
        var = StochasticProcess.VectorAutoRegressive(d, e)

        # Season 1, lag 1: [[0.5, 0.1], [0.2, 0.4]]
        phi = StochasticProcess.get_var_coefficient_matrix(var, 1, 1)
        @test phi[1, 1] == 0.5
        @test phi[1, 2] == 0.1
        @test phi[2, 1] == 0.2
        @test phi[2, 2] == 0.4

        # Season 2, lag 2: [[0.05, 0.0], [0.0, 0.05]]
        phi2 = StochasticProcess.get_var_coefficient_matrix(var, 2, 2)
        @test phi2[1, 1] == 0.05
        @test phi2[1, 2] == 0.0
        @test phi2[2, 1] == 0.0
        @test phi2[2, 2] == 0.05
    end
end
