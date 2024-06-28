module Scenarios

using ..Utils
using ..StochasticProcess

struct AbstractScenarios
    inflow::AbstractStochasticProcess
    load::AbstractStochasticProcess
end

export Scenarios

end