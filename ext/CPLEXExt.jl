module CPLEXExt

using SDDPlab
using JuMP
import CPLEX as CPLEXInterface

function SDDPlab.Resources.generate_optimizer(s::SDDPlab.Resources.CPLEX)
    optimizer = optimizer_with_attributes(CPLEXInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

end