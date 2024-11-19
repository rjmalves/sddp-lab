# Buses
LOAD = Symbol("LOAD")
DEFICIT = Symbol("DEFICIT")
# Lines
DIRECT_EXCHANGE = Symbol("DIRECT_EXCHANGE")
REVERSE_EXCHANGE = Symbol("REVERSE_EXCHANGE")
NET_EXCHANGE = Symbol("NET_EXCHANGE")
# Thermals
THERMAL_GENERATION = Symbol("THERMAL_GENERATION")
THERMAL_GENERATION_COST = Symbol("THERMAL_GENERATION_COST")
# Hydros
STORED_VOLUME = Symbol("STORAGE")
HYDRO_GENERATION = Symbol("HYDRO_GENERATION")
HYDRO_MIN_GENERATION_SLACK = Symbol("HYDRO_MIN_GENERATION_SLACK")
INFLOW = Symbol("INFLOW")
TURBINED_FLOW = Symbol("TURBINED_FLOW")
OUTFLOW = Symbol("OUTFLOW")
SPILLAGE = Symbol("SPILLAGE")
# Scenarios
ω_INFLOW = Symbol("ω_INFLOW")
# Constraints
HYDRO_BALANCE = Symbol("HYDRO_BALANCE")
LOAD_BALANCE = Symbol("LOAD_BALANCE")
MARGINAL_COST = Symbol("MARGINAL_COST")
WATER_VALUE = Symbol("WATER_VALUE")
# SDDP internals
TOTAL_COST = Symbol("TOTAL_COST")
STAGE_COST = Symbol("stage_objective")
FUTURE_COST = Symbol("bellman_term")