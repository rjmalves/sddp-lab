module GLPKExt

using SDDPlab
using JuMP
import GLPK as GLPKInterface

function SDDPlab.Resources.generate_optimizer(s::SDDPlab.Resources.GLPK)
    optimizer = optimizer_with_attributes(GLPKInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

export __validate_glpk_consistency!, generate_optimizer

end