struct Table2Process{T<:IndexedTable}
    table::T
    kw::Dict{Symbol, Any}
end

function pipeline!(t::Table2Process)
    t.kw[:axis_type] = get(t.kw, :axis_type, :auto)
    t.kw[:summarize] = get(t.kw, :summarize, (mean,sem))
    t.kw[:compute_axis] = get(t.kw, :compute_axis, :auto)
    t.kw[:fkwargs] = get(t.kw, :fkwargs, [])
    process_axis_type!(t)
    process_function!(t)
    return Table2Process(_group_apply(t), t.kw)
end

function process_axis_type!(t::Table2Process)
    x, y = t.table.index.columns[end], t.table.data
    at = t.kw[:axis_type]
    if !(eltype(x)<:Real)
        (t.kw[:axis_type] in [:discrete, :auto]) || warn("Changing to discrete axis, x values are not real numbers!")
        t.kw[:axis_type] = :discrete
    end
    bin_width = 1.0
    if t.kw[:axis_type] == :binned
        nbins = get(t.kw, :nbins, 30)
        edges = linspace(extrema(x)..., nbins+1)
        middles = (edges[2:end] .+ edges[1:end-1])./2
        indices = [searchsortedfirst(edges[2:end], s) for s in x]
        x .= middles[indices]
        bin_width = step(edges)
        t.kw[:axis_type] = :discrete
    end
    (t.kw[:axis_type] == :auto) && (t.kw[:axis_type] = :continuous)
    t.kw[:axis_type] in [:discrete, :continuous] ||
        error("Axis type $(t.kw[:axis_type]) is not supported")
    all(isnan.(y)) && (y .= bin_width)
end

function process_function!(t::Table2Process)
    if isa(t.kw[:f], Symbol)
        t.kw[:compute_axis] = get(builtin_axis, t.kw[:f], :auto)
        t.kw[:f] = builtin_funcs[t.kw[:f]]
    end
    t.kw[:fclosure] = (args...) -> t.kw[:f](Val{t.kw[:axis_type]}(), args...; t.kw[:fkwargs]...)
end

_isnan(v) = false
_isnan(v::Float64) = isnan(v)

function get_grouped_error(trend, variation, f!, xtable, t)
    splitdata = mapslices(tt -> f!(xtable, select(tt,2)), t, 2)
    nanfree = filter(isfinite, splitdata)
    all(_isnan.(keys(t, 1))) ? reducedim((x,y)->y, nanfree, 1) :
        reducedim_vec(i -> (trend(i), variation(i)), nanfree, 1)
end

function _group_apply(t::Table2Process)
    n = length(t.table.index.columns)-1
    g = mapslices(t.table, [n, n+1]) do tt
        xaxis = get_axis(keys(tt, n+1), t.kw[:axis_type], t.kw[:compute_axis])
        xtable = IndexedTable(collect(xaxis), fill(0.0, length(xaxis)), presorted = true)
        get_grouped_error(t.kw[:summarize]..., t.kw[:fclosure], xtable, select(tt, n, n+1))
    end
    filter(i -> all(isfinite.(i)), g)
end

function group_apply(df::IndexedTable; kwargs...)
    t = Table2Process(copy(df), Dict{Symbol,Any}(kwargs))
    pipeline!(t)
end
