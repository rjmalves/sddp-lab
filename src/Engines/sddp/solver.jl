"""
    create_optimizer(config) -> () -> optimizer

Return a zero-argument factory that creates a configured optimizer instance.
Supported solvers: `"GLPK"` (bundled), `"HiGHS"` (requires separate install).
"""
function create_optimizer(config::SolverConfig)
    name = config.solver_name
    attrs = config.attributes

    if name == "GLPK"
        return () -> begin
            opt = GLPK.Optimizer()
            for (k, v) in attrs
                MOI.set(opt, MOI.RawOptimizerAttribute(k), v)
            end
            return opt
        end
    elseif name == "HiGHS"
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
    else
        error(
            "Unsupported solver: $(name). Supported solvers: GLPK, HiGHS",
        )
    end
end
