"""
    create_optimizer(config) -> () -> optimizer

Return a zero-argument factory that creates a configured optimizer instance.
Supported solvers: `"HiGHS"`, `"GLPK"` (both require separate install).
"""
function create_optimizer(config::SolverConfig)
    name = config.solver_name
    attrs = config.attributes

    if name == "HiGHS"
        local HiGHSMod
        try
            HiGHSMod = Base.require(Main, :HiGHS)
        catch
            error(
                "Solver \"HiGHS\" was requested but HiGHS.jl is not installed. " *
                "Run `import Pkg; Pkg.add(\"HiGHS\")` to install it.",
            )
        end
        return () -> begin
            opt = HiGHSMod.Optimizer()
            for (k, v) in attrs
                MOI.set(opt, MOI.RawOptimizerAttribute(k), v)
            end
            return opt
        end
    elseif name == "GLPK"
        local GLPKMod
        try
            GLPKMod = Base.require(Main, :GLPK)
        catch
            error(
                "Solver \"GLPK\" was requested but GLPK.jl is not installed. " *
                "Run `import Pkg; Pkg.add(\"GLPK\")` to install it.",
            )
        end
        return () -> begin
            opt = GLPKMod.Optimizer()
            for (k, v) in attrs
                MOI.set(opt, MOI.RawOptimizerAttribute(k), v)
            end
            return opt
        end
    else
        error("Unsupported solver: $(name). Supported solvers: HiGHS, GLPK")
    end
end
