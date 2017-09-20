module GroupedErrors

import Loess, KernelDensity, IterableTables
import DataValues: DataValue
using IndexedTables
using TableTraits
using MacroTools
using StatsBase

export @splitby, @across, @x, @y, @summarize
export ProcessedTable

include("select.jl")
include("query_macro.jl")
include("plot_macro.jl")
include("pipeline.jl")
include("analysisfunctions.jl")


end
