##### List of functions to analyze data

"""
    `_locreg!(df, xaxis::Range, x, y; kwargs...)`

Apply loess regression, training the regressor with `x` and `y` and
predicting `xaxis`
"""
function _locreg!(::Val{:continuous}, xtable, t; kwargs...)
    x, y = keys(t, 1), t.data
    within = filter(t -> minimum(x)<= t <= maximum(x), keys(xtable,1))
    if length(within) > 0
        model = Loess.loess(convert(Vector{Float64},x),convert(Vector{Float64},y); kwargs...)
        prediction = Loess.predict(model,within)
    else
        prediction = Float64[]
    end
    return IndexedTable(within, prediction, presorted = true)
end


"""
    `_locreg!(df, xaxis, x, y; estimator = mean)`

In the discrete case, the function computes the estimate of `y` for
a given value of `x` using the function `estimator` (default is mean)
"""
_locreg!(::Val{:discrete}, xtable, t; estimator = mean) = aggregate_vec(estimator, t)


"""
    `_density!(df,xaxis::Range, x; kwargs...)`

Kernel density of `x`, computed along `xaxis`
"""
function _density!(::Val{:continuous}, xtable, t; kwargs...)
    xtable.data .=  KernelDensity.pdf(KernelDensity.kde(keys(t, 1); kwargs...), keys(xtable,1))
    xtable
end
"""
    `_density!(df, xaxis, x)`

Normalized histogram of `x` (which is discrete: every value is its own bin)
"""
_density!(::Val{:discrete}, xtable, t) =
    leftjoin(xtable, aggregate_vec(v -> length(v)/sum(t.data), t))

_density_axis(column, axis_type::Symbol; kwargs...) =
    (axis_type == :discrete) ? get_axis(column) :
    linspace(extrema(KernelDensity.kde(column; kwargs...).x)..., 100)

"""
    `_cumulative!(df, xaxis, x) = ecdf(df[x])(xaxis)`

Cumulative density function of `x`, computed along `xaxis`
"""
function _cumulative!(::Any, xtable, t)
    xtable.data .= ecdf(keys(t,1))(keys(xtable,1))
    xtable
end


"""
    `_hazard(df,xaxis, x; kwargs...)`

Hazard rate of `x`, computed along `xaxis`. Keyword arguments are passed to
the function computing the density
"""
_hazard!(T, xtable, t; kwargs...) =
    broadcast((x,y) -> x/(1-y), _density!(T, xtable, t; kwargs...), _cumulative!(T, xtable, t))

#### Method to compute and plot grouped error plots using the above functions

get_axis(column) = sort!(union(column))
get_axis(column, npoints::Int64) = linspace(extrema(column)..., npoints)

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

builtin_funcs = Dict(zip([:locreg, :density, :cumulative, :hazard],
    [_locreg!, _density!, _cumulative!, _hazard!]))

builtin_axis = Dict(:density => _density_axis)
