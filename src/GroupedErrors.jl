module GroupedErrors

using Statistics
import Loess, KernelDensity, IterableTables
import DataValues: DataValue, isna
import Lazy: @>
using IndexedTables
import IndexedTables: select
using TableTraits
using MacroTools
using StatsBase
using ShiftedArrays

export @splitby, @bootstrap, @across, @x, @y, @xy, @compare, @summarize, @set_attr, @>, @plot
export @xlims, @ylims
export ProcessedTable

include("select.jl")
include("query_macro.jl")
include("plot_macro.jl")
include("pipeline.jl")
include("analysisfunctions.jl")

exampletable() = joinpath(dirname(@__DIR__), "test", "tables")
exampletable(s) = joinpath(exampletable(), s)


end
