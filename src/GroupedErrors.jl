module GroupedErrors

import Loess, KernelDensity, IterableTables
import DataValues: DataValue
using IndexedTables
using TableTraits
using MacroTools
using StatsBase

export group_apply
export @given

include("pipeline.jl")
include("analysisfunctions.jl")
include("select.jl")
include("macro.jl")

end
