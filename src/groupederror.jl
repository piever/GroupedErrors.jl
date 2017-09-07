##### List of functions to analyze data

"""
    `_locreg!(df, xaxis::Range, x, y; kwargs...)`

Apply loess regression, training the regressor with `x` and `y` and
predicting `xaxis`
"""
function _locreg!(xaxis::Range, xtable, t; kwargs...)
    xtable.data .= NaN
    x, y = keys(t, 1), t.data
    within = filter(t -> Plots.ignorenan_minimum(x)<= t <= Plots.ignorenan_maximum(x), xaxis)
    if length(within) >0
        model = Loess.loess(convert(Vector{Float64},x),convert(Vector{Float64},y); kwargs...)
        xtable[within] .= Loess.predict(model,within)
    end
    return xtable
end


"""
    `_locreg!(df, xaxis, x, y; estimator = mean)`

In the discrete case, the function computes the estimate of `y` for
a given value of `x` using the function `estimator` (default is mean)
"""
_locreg!(xaxis, xtable, t; estimator = mean) = aggregate_vec(estimator, t)


"""
    `_density!(df,xaxis::Range, x; kwargs...)`

Kernel density of `x`, computed along `xaxis`
"""
function _density!(xaxis::Range, xtable, t; kwargs...)
    xtable.data .=  KernelDensity.pdf(KernelDensity.kde(keys(t, 1); kwargs...), xaxis)
    xtable
end
"""
    `_density!(df, xaxis, x)`

Normalized histogram of `x` (which is discrete: every value is its own bin)
"""
_density!(xaxis, xtable, t) =
    leftjoin(xtable, aggregate_vec(v -> length(v)/sum(t.data), t))

_density!_axis(column, axis_type::Symbol; kwargs...) =
    (axis_type == :discrete) ? get_axis(column) :
    linspace(extrema(KernelDensity.kde(column; kwargs...).x)..., 100)

"""
    `_cumulative!(df, xaxis, x) = ecdf(df[x])(xaxis)`

Cumulative density function of `x`, computed along `xaxis`
"""
function _cumulative!(xaxis, xtable, t)
    xtable.data .= ecdf(keys(t,1))(xaxis)
    xtable
end


"""
    `_hazard(df,xaxis, x; kwargs...)`

Hazard rate of `x`, computed along `xaxis`. Keyword arguments are passed to
the function computing the density
"""
_hazard(xaxis, xtable, t; kwargs...) =
    broadcast((x,y) -> x/(1-y), _density!(xaxis, xtable, t; kwargs...), _cumulative!(xaxis, xtable, t))

#### Method to compute and plot grouped error plots using the above functions

get_axis(column) = sort!(union(column))
get_axis(column, npoints::Int64) = linspace(Plots.ignorenan_minimum(column),Plots.ignorenan_maximum(column),npoints)

function get_axis(column, axis_type::Symbol, compute_axis::Symbol; kwargs...)
    if axis_type == :discrete
        return get_axis(column)
    elseif axis_type == :continuous
        return get_axis(column, 100)
    else
        error("Unexpected axis_type: only :discrete and :continuous allowed!")
    end
end

get_axis(column, axis_type::Symbol, compute_axis; kwargs...) =
    compute_axis(column, axis_type; kwargs...)

# f is the function used to analyze dataset: define it as nan when it is not defined,
# the input is: dataframe used, points chosen on the x axis, x (and maybe y) column labels
# the output is the y value for the given xvalues

get_symbol(s::Symbol) = s
get_symbol(s) = s[1]

function get_groupederror(trend, variation, f!, xaxis, xtable, t, ce; kwargs...)
    if get_symbol(ce) != :bootstrap
        splitdata = mapslices(tt -> f!(xaxis, xtable, select(tt,2); kwargs...), t, 2)
    else
        ns = ce[2]
        ref_data = select(t,2)
        large_table = IndexedTable(repeat(collect(1:ns), inner = length(xaxis)),
            repeat(collect(xaxis), outer = ns), zeros(ns*length(xaxis)), presorted = true)
        splitdata = mapslices(large_table, 1) do tt
            nd = length(ref_data.data)
            perm = rand(1:nd,nd)
            permuted_data = IndexedTable(keys(ref_data,1)[rand(1:nd,nd)], ref_data.data[rand(1:nd,nd)])
            f!(xaxis, xtable, permuted_data; kwargs...)
        end
    end
    nanfree = filter(isfinite, splitdata)
    if get_symbol(ce) == :none
        return reducedim((x,y)->y, nanfree, 1)
    else
        return reducedim_vec(i -> (trend(i), variation(i)), nanfree, 1)
    end
end

"""

    groupapply(f::Function, df, args...;
                axis_type = :auto, compute_error = :none, group = Symbol[],
                summarize = (get_symbol(compute_error) == :bootstrap) ? (mean, std) : (mean, sem),
                nbins = 30,
                kwargs...)

Split `df` by `group`. Then apply `get_groupederror` to get a population summary of the grouped data.
Output is a `GroupedError` with error computed according to the keyword `compute_error`.
It can be plotted using `plot(g::GroupedError)`
Seriestype can be specified to be `:path`, `:scatter` or `:bar`
"""
function groupapply(f!::Function, args...;
                    axis_type = :auto, compute_error = :none, group = (),
                    summarize = (get_symbol(compute_error) == :bootstrap) ? (mean, std) : (mean, sem),
                    nbins = 30,
                    compute_axis = :auto,
                    kwargs...)
    added_cols = Symbol[]
    if !(eltype(args[1])<:Real)
        (axis_type in [:discrete, :auto]) || warn("Changing to discrete axis, x values are not real numbers!")
        axis_type = :discrete
    end

    if axis_type == :binned
        edges = linspace(Plots.ignorenan_minimum(args[1]),
            Plots.ignorenan_maximum(args[1]), nbins+1)
        middles = (edges[2:end] .+ edges[1:end-1])./2
        indices = [searchsortedfirst(edges[2:end], x) for x in args[1]]
        x = middles[indices]
        bin_width = step(edges)
        axis_type = :discrete
    else
        bin_width = 1.0
        (axis_type == :auto) && (axis_type = :continuous)
        x = (axis_type == :continuous) ? Float64.(args[1]) : args[1]
    end
    y = length(args) == 1 ? fill(bin_width, length(x)) : Float64.(args[2])
    # Add default for :across and :bootstrap
    if compute_error == :across
        row_name = collect(1:length(x))
        ce = (:across, row_name)
    elseif compute_error == :bootstrap
        ce = (:bootstrap, 1000)
    else
        ce = compute_error
    end

    aug_group = if group == ()
        (fill("y1", length(x)),)
    elseif isa(group, AbstractArray)
        (group,)
    else
        group
    end
    n = length(aug_group)+1

    df = IndexedTable(aug_group..., get_symbol(ce) == :across ? ce[2] :  zeros(length(x)), x, y)
    g = mapslices(df, [n, n+1]) do t
        xaxis = get_axis(keys(t, n+1), axis_type, compute_axis)
        xtable = IndexedTable(collect(xaxis), fill(0.0, length(xaxis)), presorted = true)
        get_groupederror(summarize..., f!, xaxis, xtable, select(t, n, n+1), ce; kwargs...)
    end
    filter(i -> all(isfinite.(i)), g)
end

builtin_funcs = Dict(zip([:locreg, :density, :cumulative, :hazard],
    [_locreg!, _density!, _cumulative!, _hazard]))

builtin_axis = Dict(:density => _density!_axis)

"""
    groupapply(s::Symbol, df, args...; kwargs...)

`s` can be `:locreg`, `:density`, `:cumulative` or `:hazard`, in which case the corresponding built in
analysis function is used. `s` can also be a symbol of a column of `df`, in which case the call
is equivalent to `groupapply(:locreg, df, args[1], s; kwargs...)`
"""
function groupapply(s::Symbol, args...; kwargs...)
    if s in keys(builtin_funcs)
        analysisfunction = builtin_funcs[s]
        return groupapply(analysisfunction, args...;
            compute_axis = get(builtin_axis, s, :auto), kwargs...)
    else
        error("$s is not supported")
    end
end

"""
    groupapply(df::AbstractDataFrame, x, y; kwargs...)

Equivalent to `groupapply(:locreg, df::AbstractDataFrame, x, y; kwargs...)`
"""

groupapply(x::AbstractArray, y; kwargs...) = groupapply(_locreg!, x, y; kwargs...)
