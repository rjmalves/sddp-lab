module GurobiExt

using SDDPlab
using JuMP
import Gurobi as GurobiInterface

function SDDPlab.Resources.generate_optimizer(s::SDDPlab.Resources.Gurobi)
    optimizer = optimizer_with_attributes(GurobiInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

end