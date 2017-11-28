__precompile__()
module GroupedErrors

import Loess, KernelDensity, IterableTables
import DataValues: DataValue
import Lazy: @>
using IndexedTables
using TableTraits
using MacroTools
using StatsBase
using NamedTuples

export @splitby, @bootstrap, @across, @x, @y, @xy, @compare, @summarize, @set_attr, @>, @plot
export ProcessedTable

include("select.jl")
include("query_macro.jl")
include("plot_macro.jl")
include("pipeline.jl")
include("analysisfunctions.jl")


end
