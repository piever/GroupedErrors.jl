function pipeline(df::Table2Process)
    cols, kw = df.table, copy(df.kw)
    kw[:axis_type] = get(kw, :axis_type, :auto)
    kw[:compute_axis] = get(kw, :compute_axis, :auto)
    kw[:compute_error] = get(kw, :compute_error, :none)
    if isa(kw[:compute_error], Number)
        kw[:summarize] = get(kw, :summarize, (mean,std))
    else
        kw[:summarize] = get(kw, :summarize, (mean,sem))
    end
    kw[:acrossall] = get(kw, :acrossall, false)
    kw[:fkwargs] = get(kw, :fkwargs, [])
    kw[:xreduce] = get(kw, :xreduce, false)
    kw[:yreduce] = get(kw, :yreduce, false)
    kw[:plot_kwargs] = get(kw, :plot_kwargs, [])
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
    if !isa(compute_error, Integer)
        splitdata = mapslices(tt -> f!(xtable, select(tt,2)), t, 2)
    else
        ns = compute_error
        ref_data = select(t,2)
        xaxis = columns(xtable, 1)
        large_table = IndexedTable(repeat(collect(1:ns), inner = length(xaxis)),
            repeat(xaxis, outer = ns), zeros(ns*length(xaxis)), presorted = true)
        splitdata = mapslices(large_table, 1) do tt
            nd = length(ref_data.data)
            perm = rand(1:nd,nd)
            permuted_data = IndexedTable(keys(ref_data,1)[rand(1:nd,nd)], ref_data.data[rand(1:nd,nd)])
            f!(xtable, permuted_data)
        end
    end
    nanfree = filter(isfinite, splitdata)
    if compute_error == :none
        return reducedim((x,y)->y, nanfree, 1)
    else
        return reducedim_vec(i -> (trend(i), variation(i)), nanfree, 1)
    end
end

function _group_apply(t::Table2Process)
    n = length(t.table.index.columns)-1
    if t.kw[:axis_type] == :pointbypoint
        if (t.kw[:xreduce] == false) || (t.kw[:yreduce] == false)
            t.kw[:compare] && error("can't compare without xreduce and yreduce")
            return t.table
        end
        w  = aggregate_vec(v -> (t.kw[:xreduce](map(i->i[1], v)), t.kw[:yreduce](map(i->i[2], v))), t.table)
        if t.kw[:compare]
            single_w = pick(1)(w)
            a, b = unique(single_w.index.columns[n])
            return innerjoin(select(select(single_w, n => t -> t == a),(1:n-1)..., n+1),
                select(select(single_w, n => t -> t == b),(1:n-1)..., n+1))
        else
            return w
        end
    else
        g = mapslices(t.table, [n, n+1]) do tt
            xaxis = get_axis(keys(tt, n+1), t.kw[:axis_type], t.kw[:compute_axis])
            xtable = IndexedTable(collect(xaxis), fill(0.0, length(xaxis)), presorted = true)
            get_grouped_error(t.kw[:summarize]..., t.kw[:fclosure], xtable, select(tt, n, n+1), t.kw[:compute_error])
        end
        return filter(i -> all(isfinite.(i)), g)
    end
end
