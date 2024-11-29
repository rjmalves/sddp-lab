module ClpExt

using SDDPlab
using JuMP
import Clp as ClpInterface

function SDDPlab.Resources.generate_optimizer(s::SDDPlab.Resources.CLP)
    optimizer = optimizer_with_attributes(ClpInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

end