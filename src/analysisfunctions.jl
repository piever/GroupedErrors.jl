#### Auxiliary function

tablify(xaxis, data) = table(collect(xaxis), data, names = [:x, :y], pkey = :x, presorted = true)

function tablify(xaxis, data::IndexedTables.AbstractIndexedTable, val = 0.0)
    extra_axis = setdiff(xaxis, columns(data, :x))
    merge(tablify(extra_axis, fill(val, length(extra_axis))), data)
end

##### List of functions to analyze data

"""
    `_locreg(df, xaxis::Range, x, y; kwargs...)`

Apply loess regression, training the regressor with `x` and `y` and
predicting `xaxis`
"""
function _locreg(::Val{:continuous}, xaxis, t; kwargs...)
    x, y = columns(t, :x), columns(t, :y)
    within = filter(t -> minimum(x)<= t <= maximum(x), xaxis)
    if length(within) > 0
        model = Loess.loess(convert(Vector{Float64},x),convert(Vector{Float64},y); kwargs...)
        prediction = Loess.predict(model,within)
    else
        prediction = Float64[]
    end
    tablify(within, prediction)
end

"""
    `_locreg(df, xaxis, x, y; estimator = mean)`

In the discrete case, the function computes the estimate of `y` for
a given value of `x` using the function `estimator` (default is mean)
"""
function _locreg(::Val{:discrete}, xaxis, t; estimator = mean)
    if column(t, :y)[1] isa ShiftedArray
        v = reduce_vec(estimator, column(t, :y), xaxis)
        inds = find(!ismissing, v)
        table(xaxis[inds], convert(Vector{Float64}, view(v, inds)), names = [:x, :y],
            copy = false, presorted = true)
    else
        groupby((:y => estimator, ), t, :x, select = :y)
    end
end

"""
    `_density(df,xaxis::Range, x; kwargs...)`

Kernel density of `x`, computed along `xaxis`
"""
function _density(::Val{:continuous}, xaxis, t; kwargs...)
    data = KernelDensity.pdf(KernelDensity.kde(columns(t, :x); kwargs...), xaxis)
    tablify(xaxis, data)
end

"""
    `_density(df, xaxis, x)`

Normalized histogram of `x` (which is discrete: every value is its own bin)
"""
function _density(::Val{:discrete}, xaxis, t; normalize = true)
    s = normalize ? reduce(+, t, select = :y) : 1.0
    small_table = groupby((:y => v -> length(v)/s, ), t, :x, select = :y)
    tablify(xaxis, small_table, 0.0)
end

_density_axis(column, axis_type::Symbol; kwargs...) =
    (axis_type == :discrete) ? get_axis(column) :
    linspace(extrema(KernelDensity.kde(column; kwargs...).x)..., 100)

"""
    `_cumulative!(df, xaxis, x) = ecdf(df[x])(xaxis)`

Cumulative density function of `x`, computed along `xaxis`
"""
function _cumulative(T, xaxis, t)
    data = ecdf(columns(t, :x))(xaxis)
    tablify(xaxis, data)
end

"""
    `_hazard(df,xaxis, x; kwargs...)`

Hazard rate of `x`, computed along `xaxis`. Keyword arguments are passed to
the function computing the density
"""
function _hazard(T, xaxis, t; kwargs...)
    data_pdf = columns(_density(T, xaxis, t; kwargs...), :y)
    data_cdf = columns(_cumulative(T, xaxis, t), :y)
    bin_size = t[1].y
    tablify(xaxis, @.(data_pdf/(1 + bin_size * data_pdf - data_cdf)))
end

#### Method to compute and plot grouped error plots using the above functions

get_axis(column::AbstractArray{<:Range}) = column[1]
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
    [_locreg, _density, _cumulative, _hazard]))

builtin_axis = Dict(:density => _density_axis)
