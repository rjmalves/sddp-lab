import SDDPlab: Engines

using SDDP: SDDP

SINGLE_CUT_DICT = convert(Dict{String,Any}, Dict())
MULTI_CUT_DICT = convert(Dict{String,Any}, Dict())

@testset "engines-sddp-cut-types" begin
    @testset "single-cut-valid" begin
        d, e = __renew(SINGLE_CUT_DICT)
        result = Engines.SingleCut(d, e)
        @test typeof(result) === Engines.SingleCut
        @test length(e) == 0
    end

    @testset "multi-cut-valid" begin
        d, e = __renew(MULTI_CUT_DICT)
        result = Engines.MultiCut(d, e)
        @test typeof(result) === Engines.MultiCut
        @test length(e) == 0
    end

    @testset "generate-cut-type-single" begin
        ct = Engines.generate_cut_type(Engines.SingleCut())
        @test ct === SDDP.SINGLE_CUT
        @test typeof(ct) === SDDP.CutType
    end

    @testset "generate-cut-type-multi" begin
        ct = Engines.generate_cut_type(Engines.MultiCut())
        @test ct === SDDP.MULTI_CUT
        @test typeof(ct) === SDDP.CutType
    end

    @testset "cut-type-kind-factory-single" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "cut_type" =>
                Dict{String,Any}("kind" => "SingleCut", "params" => Dict{String,Any}()),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.cut_type) === Engines.SingleCut
    end

    @testset "cut-type-kind-factory-multi" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "cut_type" =>
                Dict{String,Any}("kind" => "MultiCut", "params" => Dict{String,Any}()),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.cut_type) === Engines.MultiCut
    end

    @testset "cut-type-backward-compat-policy" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result !== nothing
        @test typeof(result) === Engines.SDDPPolicyTaskDefinition
        @test typeof(result.cut_type) === Engines.SingleCut
    end

    @testset "cut-type-invalid-kind" begin
        d = Dict{String,Any}(
            "convergence" => Dict{String,Any}(
                "min_iterations" => 10,
                "max_iterations" => 128,
                "stopping_criteria" => Dict{String,Any}(
                    "kind" => "IterationLimit",
                    "params" => Dict{String,Any}("num_iterations" => 128),
                ),
            ),
            "risk_measure" =>
                Dict{String,Any}("kind" => "Expectation", "params" => Dict{String,Any}()),
            "parallel_scheme" =>
                Dict{String,Any}("kind" => "Serial", "params" => Dict{String,Any}()),
            "cut_type" => Dict{String,Any}(
                "kind" => "NonExistentCutType", "params" => Dict{String,Any}()
            ),
        )
        e = CompositeException()
        result = Engines.SDDPPolicyTaskDefinition(d, e)
        @test result === nothing
        @test length(e) > 0
    end
end
