import SDDPlab: Utils

@testset "schema" begin
    @testset "predicate-factories" begin
        @testset "positive" begin
            c = Utils.positive()
            @test c.predicate(1) == true
            @test c.predicate(0) == false
            @test c.predicate(-1) == false
        end

        @testset "non_negative" begin
            c = Utils.non_negative()
            @test c.predicate(0) == true
            @test c.predicate(1) == true
            @test c.predicate(-1) == false
        end

        @testset "in_range" begin
            c = Utils.in_range(0, 1)
            @test c.predicate(0) == true
            @test c.predicate(0.5) == true
            @test c.predicate(1) == true
            @test c.predicate(-0.1) == false
            @test c.predicate(1.1) == false
        end

        @testset "in_range_exclusive" begin
            c = Utils.in_range_exclusive(0, 1)
            @test c.predicate(0) == false
            @test c.predicate(0.5) == true
            @test c.predicate(1) == false
        end

        @testset "greater_than" begin
            c = Utils.greater_than(5)
            @test c.predicate(6) == true
            @test c.predicate(5) == false
        end

        @testset "less_than" begin
            c = Utils.less_than(5)
            @test c.predicate(4) == true
            @test c.predicate(5) == false
        end

        @testset "non_empty" begin
            c = Utils.non_empty()
            @test c.predicate("abc") == true
            @test c.predicate("") == false
        end

        @testset "matches" begin
            c = Utils.matches(r"^[a-z]+$")
            @test c.predicate("abc") == true
            @test c.predicate("ABC") == false
            @test c.predicate("") == false
        end

        @testset "unique_in" begin
            c = Utils.unique_in("id")
            @test c.name == "unique in id"
            @test c.predicate(1) == true
            @test c.predicate("anything") == true
        end
    end

    @testset "validate_schema!" begin
        @testset "valid-dict" begin
            d = Dict{String,Any}("id" => 1, "name" => "bus1", "cost" => 10.0)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
                Utils.FieldRule("name", String; constraints = [Utils.non_empty()]),
                Utils.FieldRule("cost", Float64; constraints = [Utils.positive()]),
            ]
            @test Utils.validate_schema!(d, schema, e) == true
            @test length(e) == 0
        end

        @testset "missing-required-key" begin
            d = Dict{String,Any}("name" => "bus1")
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
                Utils.FieldRule("name", String),
            ]
            @test Utils.validate_schema!(d, schema, e) == false
            @test length(e) == 1
            @test e.exceptions[1] isa ErrorException
            @test e.exceptions[1].msg == "Key 'id' not found in dictionary"
        end

        @testset "missing-two-required-keys" begin
            d = Dict{String,Any}("other" => 42)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer),
                Utils.FieldRule("name", String),
            ]
            @test Utils.validate_schema!(d, schema, e) == false
            @test length(e) == 2
            @test e.exceptions[1] isa ErrorException
            @test e.exceptions[1].msg == "Key 'id' not found in dictionary"
            @test e.exceptions[2] isa ErrorException
            @test e.exceptions[2].msg == "Key 'name' not found in dictionary"
        end

        @testset "wrong-type" begin
            d = Dict{String,Any}("id" => "not_a_number")
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer),
            ]
            @test Utils.validate_schema!(d, schema, e) == false
            @test length(e) == 1
            @test e.exceptions[1] isa ErrorException
        end

        @testset "constraint-violation" begin
            d = Dict{String,Any}("id" => -5)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
            ]
            @test Utils.validate_schema!(d, schema, e) == false
            @test length(e) == 1
            @test e.exceptions[1] isa AssertionError
            @test e.exceptions[1].msg == "id (-5) must be positive"
        end

        @testset "multiple-violations-across-fields" begin
            d = Dict{String,Any}("id" => -1, "alpha" => 2.0)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
                Utils.FieldRule("alpha", Float64; constraints = [Utils.in_range(0, 1)]),
            ]
            @test Utils.validate_schema!(d, schema, e) == false
            @test length(e) == 2
            @test e.exceptions[1] isa AssertionError
            @test e.exceptions[1].msg == "id (-1) must be positive"
            @test e.exceptions[2] isa AssertionError
            @test e.exceptions[2].msg == "alpha (2.0) must be in [0, 1]"
        end

        @testset "optional-field-missing" begin
            d = Dict{String,Any}("id" => 1)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
                Utils.FieldRule("alpha", Float64; required = false, constraints = [Utils.in_range(0, 1)]),
            ]
            @test Utils.validate_schema!(d, schema, e) == true
            @test length(e) == 0
        end

        @testset "optional-field-present-wrong-type" begin
            d = Dict{String,Any}("id" => 1, "alpha" => "not_a_number")
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer),
                Utils.FieldRule("alpha", Float64; required = false),
            ]
            @test Utils.validate_schema!(d, schema, e) == false
            @test length(e) == 1
            @test e.exceptions[1] isa ErrorException
        end

        @testset "entity-label-in-error-messages" begin
            d = Dict{String,Any}("id" => -5)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
            ]
            @test Utils.validate_schema!(d, schema, e; entity_label = "Bus 1") == false
            @test length(e) == 1
            @test e.exceptions[1] isa AssertionError
            @test e.exceptions[1].msg == "Bus 1 - id (-5) must be positive"
        end

        @testset "empty-entity-label" begin
            d = Dict{String,Any}("id" => -5)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
            ]
            @test Utils.validate_schema!(d, schema, e; entity_label = "") == false
            @test length(e) == 1
            @test e.exceptions[1].msg == "id (-5) must be positive"
        end
    end

    @testset "validate_schema_keys_types!" begin
        @testset "skips-constraints" begin
            d = Dict{String,Any}("id" => -5, "alpha" => 99.0)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
                Utils.FieldRule("alpha", Float64; constraints = [Utils.in_range(0, 1)]),
            ]
            @test Utils.validate_schema_keys_types!(d, schema, e) == true
            @test length(e) == 0
        end

        @testset "detects-missing-key" begin
            d = Dict{String,Any}("alpha" => 0.5)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer),
                Utils.FieldRule("alpha", Float64),
            ]
            @test Utils.validate_schema_keys_types!(d, schema, e) == false
            @test length(e) == 1
            @test e.exceptions[1] isa ErrorException
            @test e.exceptions[1].msg == "Key 'id' not found in dictionary"
        end

        @testset "detects-wrong-type" begin
            d = Dict{String,Any}("id" => "not_a_number")
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer; constraints = [Utils.positive()]),
            ]
            @test Utils.validate_schema_keys_types!(d, schema, e) == false
            @test length(e) == 1
            @test e.exceptions[1] isa ErrorException
        end

        @testset "optional-field-missing-ok" begin
            d = Dict{String,Any}("id" => 1)
            e = CompositeException()
            schema = [
                Utils.FieldRule("id", Integer),
                Utils.FieldRule("alpha", Float64; required = false),
            ]
            @test Utils.validate_schema_keys_types!(d, schema, e) == true
            @test length(e) == 0
        end
    end
end
