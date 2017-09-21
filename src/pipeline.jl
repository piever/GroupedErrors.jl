function pipeline(df::Table2Process)
    cols, kw = df.table, copy(df.kw)
    kw[:axis_type] = get(kw, :axis_type, :auto)
    kw[:summarize] = get(kw, :summarize, (mean,sem))
    kw[:compute_axis] = get(kw, :compute_axis, :auto)
    kw[:compute_error] = get(kw, :compute_error, false)
    kw[:acrossall] = get(kw, :acrossall, false)
    kw[:fkwargs] = get(kw, :fkwargs, [])
    kw[:xreduce] = get(kw, :xreduce, mean)
    kw[:yreduce] = get(kw, :yreduce, mean)
    t = process_axis_type!(cols, kw)
    process_function!(t)
    return ProcessedTable(_group_apply(t), t.kw)
end

function process_axis_type!(cols, kw)
    x, y = cols[end-1:end]
    kw[:acrossall] && (cols[end-2] .= collect(1.:Float64(length(cols[end-2]))))
    at = kw[:axis_type]
    (at == :pointbypoint) && return Table2Process(IndexedTable(Columns(cols[1:end-2]...), Columns(x, y)), kw)

    if !(eltype(x)<:Real)
        (kw[:axis_type] in [:discrete, :auto]) || warn("Changing to discrete axis, x values are not real numbers!")
        kw[:axis_type] = :discrete
    end
    bin_width = 1.0
    if kw[:axis_type] == :binned
        nbins = get(kw, :nbins, 30)
        edges = linspace(extrema(x)..., nbins+1)
        middles = (edges[2:end] .+ edges[1:end-1])./2
        indices = [searchsortedfirst(edges[2:end], s) for s in x]
        x .= middles[indices]
        bin_width = step(edges)
        kw[:axis_type] = :discrete
    end
    (kw[:axis_type] == :auto) && (kw[:axis_type] = :continuous)
    kw[:axis_type] in [:discrete, :continuous] ||
        error("Axis type $(kw[:axis_type]) is not supported")
    all(isnan.(y)) && (y .= bin_width)
    Table2Process(IndexedTable(cols...), kw)
end

function process_function!(t::Table2Process)
    if isa(t.kw[:f], Symbol)
        t.kw[:compute_axis] = get(builtin_axis, t.kw[:f], :auto)
        t.kw[:f] = builtin_funcs[t.kw[:f]]
    end
    t.kw[:fclosure] = (args...) -> t.kw[:f](Val{t.kw[:axis_type]}(), args...; t.kw[:fkwargs]...)
end


function get_grouped_error(trend, variation, f!, xtable, t, compute_error)
    splitdata = mapslices(tt -> f!(xtable, select(tt,2)), t, 2)
    nanfree = filter(isfinite, splitdata)
    compute_error == :across ? reducedim_vec(i -> (trend(i), variation(i)), nanfree, 1) :
        reducedim((x,y)->y, nanfree, 1)
end

function _group_apply(t::Table2Process)
    n = length(t.table.index.columns)-1
    if t.kw[:axis_type] == :pointbypoint
        return select(aggregate_vec(v -> (t.kw[:xreduce](map(i->i[1], v)), t.kw[:yreduce](map(i->i[2], v))), t.table),(1:n)...)
    else
        g = mapslices(t.table, [n, n+1]) do tt
            xaxis = get_axis(keys(tt, n+1), t.kw[:axis_type], t.kw[:compute_axis])
            xtable = IndexedTable(collect(xaxis), fill(0.0, length(xaxis)), presorted = true)
            get_grouped_error(t.kw[:summarize]..., t.kw[:fclosure], xtable, select(tt, n, n+1), t.kw[:compute_error])
        end
        return filter(i -> all(isfinite.(i)), g)
    end
end
