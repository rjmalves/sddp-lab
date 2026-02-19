"""
Symbol key for bus load demand (MW).
"""
LOAD = Symbol("LOAD")

"""
Symbol key for unserved energy / load deficit (MW).
"""
DEFICIT = Symbol("DEFICIT")

"""
Symbol key for power exported from a bus across a transmission line (MW).
"""
DIRECT_EXCHANGE = Symbol("DIRECT_EXCHANGE")

"""
Symbol key for power imported into a bus across a transmission line (MW).
"""
REVERSE_EXCHANGE = Symbol("REVERSE_EXCHANGE")

"""
Symbol key for net exchange flow on a transmission line (MW).
"""
NET_EXCHANGE = Symbol("NET_EXCHANGE")

"""
Symbol key for thermal plant generation dispatch (MW).
"""
THERMAL_GENERATION = Symbol("THERMAL_GENERATION")

"""
Symbol key for thermal plant generation cost (currency).
"""
THERMAL_GENERATION_COST = Symbol("THERMAL_GENERATION_COST")

"""
Symbol key for non-controllable (renewable) generation dispatch (MW).
"""
NC_GENERATION = Symbol("NC_GENERATION")

"""
Symbol key for non-controllable generation curtailment (MW).
"""
NC_CURTAILMENT = Symbol("NC_CURTAILMENT")

"""
Symbol key for energy contract dispatch (MW), positive = import.
"""
CONTRACT_DISPATCH = Symbol("CONTRACT_DISPATCH")

"""
Symbol key for pumped flow rate through a pumping station (m³/s).
"""
PUMPED_FLOW = Symbol("PUMPED_FLOW")

"""
Symbol key for power consumed by a pumping station (MW).
"""
PUMP_POWER = Symbol("PUMP_POWER")

"""
Symbol key for stored volume in a hydro reservoir (hm³).
"""
STORED_VOLUME = Symbol("STORAGE")

"""
Symbol key for hydro plant generation dispatch (MW).
"""
HYDRO_GENERATION = Symbol("HYDRO_GENERATION")

"""
Symbol key for slack on minimum hydro generation constraint (MW).
"""
HYDRO_MIN_GENERATION_SLACK = Symbol("HYDRO_MIN_GENERATION_SLACK")

"""
Symbol key for natural inflow to a hydro reservoir (m³/s).
"""
INFLOW = Symbol("INFLOW")

"""
Symbol key for turbined flow through a hydro turbine (m³/s).
"""
TURBINED_FLOW = Symbol("TURBINED_FLOW")

"""
Symbol key for total outflow from a hydro reservoir (m³/s).
"""
OUTFLOW = Symbol("OUTFLOW")

"""
Symbol key for spillage from a hydro reservoir (m³/s).
"""
SPILLAGE = Symbol("SPILLAGE")

"""
Symbol key for block-level stored volume (hm³), used when inner load blocks are active.
"""
BLOCK_STORAGE = Symbol("BLOCK_STORAGE")

"""
Symbol key for inflow non-negativity slack variable (m³/s).
"""
INFLOW_SLACK = Symbol("INFLOW_SLACK")

"""
Symbol key for noise adjustment slack variable used in AR model corrections.
"""
NOISE_ADJUSTMENT_SLACK = Symbol("NOISE_ADJUSTMENT_SLACK")

"""
Symbol key for the inflow noise realization (ω) in autoregressive models.
"""
ω_INFLOW = Symbol("ω_INFLOW")

"""
Symbol key for stage-to-hydro productivity parameter (MW·s/hm³).
"""
STCHP = Symbol("STCHP")

"""
Symbol key for hydro water balance constraint dual (water value, currency/hm³).
"""
HYDRO_BALANCE = Symbol("HYDRO_BALANCE")

"""
Symbol key for bus load balance constraint dual (marginal cost of energy, currency/MWh).
"""
LOAD_BALANCE = Symbol("LOAD_BALANCE")

"""
Symbol key for nodal marginal cost (currency/MWh).
"""
MARGINAL_COST = Symbol("MARGINAL_COST")

"""
Symbol key for water value at a hydro reservoir (currency/hm³).
"""
WATER_VALUE = Symbol("WATER_VALUE")

"""
Symbol key for total operating cost in a stage (currency).
"""
TOTAL_COST = Symbol("TOTAL_COST")

"""
Symbol key for the stage objective value (currency), maps to SDDP.jl `stage_objective`.
"""
STAGE_COST = Symbol("stage_objective")

"""
Symbol key for the Bellman / future cost function value (currency).
"""
FUTURE_COST = Symbol("bellman_term")

"""
Symbol key for vertex coverage distance in the Bellman approximation.
"""
VERTEX_COVERAGE_DISTANCE = Symbol("bellman_vertex_coverage_distance")
