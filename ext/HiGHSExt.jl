module HiGHSExt

using SDDPlab
using JuMP
import HiGHS as HiGHSInterface

function SDDPlab.Resources.generate_optimizer(s::SDDPlab.Resources.HiGHS)
    optimizer = optimizer_with_attributes(HiGHSInterface.Optimizer)
    for (key, value) in s.params
        set_attribute(optimizer, key, value)
    end
    return optimizer
end

end