# JuMP and SDDP must be imported at file scope because macros (@variable,
# @stageobjective) need them resolved at parse time, before try/catch.
import JuMP
import SDDP
import HiGHS
import Logging

let
    try
        redirect_stdout(devnull) do
            redirect_stderr(devnull) do
                Logging.with_logger(Logging.NullLogger()) do
                    model = SDDP.PolicyGraph(
                        SDDP.LinearGraph(2);
                        sense = :Min,
                        lower_bound = 0.0,
                        optimizer = () -> begin
                            opt = HiGHS.Optimizer()
                            JuMP.MOI.set(opt, JuMP.MOI.Silent(), true)
                            opt
                        end,
                    ) do sp, node
                        JuMP.@variable(sp, 0 <= volume <= 100, SDDP.State, initial_value = 50)
                        JuMP.@variable(sp, 0 <= thermal <= 50)
                        JuMP.@variable(sp, 0 <= deficit <= 100)
                        JuMP.@variable(sp, inflow)
                        JuMP.@constraint(sp, volume.out == volume.in + inflow - thermal)
                        JuMP.@constraint(sp, thermal + deficit >= 30)
                        SDDP.@stageobjective(sp, 10.0 * thermal + 500.0 * deficit)
                        SDDP.parameterize(sp, [10.0, 20.0, 30.0]) do omega
                            JuMP.fix(inflow, omega)
                        end
                    end

                    SDDP.train(
                        model;
                        iteration_limit = 3,
                        risk_measure = SDDP.Expectation(),
                        print_level = 0,
                        log_every_iteration = false,
                    )
                end
            end
        end
    catch e
        @debug "SDDPlab precompile workload failed (non-fatal): $e"
    end
end
