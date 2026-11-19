struct PhysicalUnit
    name::String
    symbol::String
    category::Symbol
end

const MW = PhysicalUnit("megawatt", "MW", :power)
const MWh = PhysicalUnit("megawatt-hour", "MWh", :energy)
const HM3 = PhysicalUnit("cubic hectometer", "hm3", :volume)
const M3_PER_S = PhysicalUnit("cubic meters per second", "m3/s", :flow)
const DOLLAR_PER_MWH = PhysicalUnit("dollars per megawatt-hour", "\$/MWh", :cost_rate)
const DOLLAR = PhysicalUnit("dollars", "\$", :cost)
const HOURS = PhysicalUnit("hours", "h", :time)
const DIMENSIONLESS = PhysicalUnit("dimensionless", "-", :dimensionless)

struct UnitConversion
    source::PhysicalUnit
    target::PhysicalUnit
    factor::Float64
end

# Conversion factors assume a 30-day month: 720 * 3600 / 1e6 = 2.592
const UNIT_CONVERSIONS = Dict{Tuple{PhysicalUnit,PhysicalUnit},UnitConversion}(
    (M3_PER_S, HM3) => UnitConversion(M3_PER_S, HM3, 2.592),
    (HM3, M3_PER_S) => UnitConversion(HM3, M3_PER_S, 1.0 / 2.592),
    (MW, MWh) => UnitConversion(MW, MWh, 1.0),
    (MWh, MW) => UnitConversion(MWh, MW, 1.0),
)
