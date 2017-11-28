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
    (kw[:axis_type] == :pointbypoint) || process_function!(t)
    return ProcessedTable(_group_apply(t), t.kw)
end

function process_axis_type!(cols, kw)
    n_grp = length(cols)- 3 - kw[:compare]
    pkey_vec = vcat([Symbol(:s, i) for i in 1:n_grp], kw[:compare] ? [:compare, :across] : [:across])
    col_names = vcat(pkey_vec, [:x, :y])
    pkey_tup = tuple(pkey_vec...)
    x, y = cols[end-1:end]
    kw[:acrossall] && (cols[end-2] .= collect(1.:Float64(length(cols[end-2]))))
    at = kw[:axis_type]
    (at == :pointbypoint) && return Table2Process(table(cols[1:end-2]..., x, y, names = col_names, pkey = pkey_tup), kw)

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
        x_binned = middles[indices]
        bin_width = step(edges)
        kw[:axis_type] = :discrete
        cols = tuple(cols[1:end-2]..., x_binned, cols[end])
    end
    (kw[:axis_type] == :auto) && (kw[:axis_type] = :continuous)
    kw[:axis_type] in [:discrete, :continuous] ||
        error("Axis type $(kw[:axis_type]) is not supported")
    if all(isnan.(y))
        if kw[:axis_type] == :discrete
            y .= bin_width
        else
            y .= 0.0
        end
    end
    Table2Process(table(cols..., names = col_names, pkey = pkey_tup), kw)
end

function process_function!(t::Table2Process)
    if isa(t.kw[:f], Symbol)
        t.kw[:compute_axis] = get(builtin_axis, t.kw[:f], :auto)
        t.kw[:f] = builtin_funcs[t.kw[:f]]
    end
    t.kw[:fclosure] = (args...) -> t.kw[:f](Val{t.kw[:axis_type]}(), args...; t.kw[:fkwargs]...)
end

function get_grouped_error(trend, variation, f, xaxis, split_table, compute_error)
    if !isa(compute_error, Integer)
        subject_table = groupby(tt -> f(xaxis, table(tt)), split_table, flatten = true)
    else
        ns = compute_error
        large_table = table(repeat(collect(1:ns), inner = length(xaxis)),
            repeat(xaxis, outer = ns), zeros(ns*length(xaxis)), names = [:across, :x, :y],
            pkey = :across, presorted = true)
        subject_table = groupby(large_table, flatten = true) do tt
            nd = length(split_table)
            perm = rand(1:nd, nd)
            permuted_data = table(columns(split_table, :x)[perm], columns(split_table, :x)[perm],
                names = [:x, :y])
            f(xaxis, permuted_data)
        end
    end
    nanfree = filter(_isfinite, subject_table)
    if compute_error == :none
        return select(nanfree, (:x, :y))
    else
        return groupby((:y => trend, :err => variation), nanfree, :x, select = :y)
    end
end

_isfinite(t) = true
_isfinite(t::Number) = isfinite(t)
_isfinite(t::Union{Tuple, NamedTuple}) = all(_isfinite.(t))

function _group_apply(t::Table2Process)
    n = eltype(t.table).parameters.length-3
    if t.kw[:axis_type] == :pointbypoint
        if (t.kw[:xreduce] == false) || (t.kw[:yreduce] == false)
            t.kw[:compare] && error("can't compare without xreduce and yreduce")
            g = t.table
        elseif !t.kw[:compare]
            g = groupby((:x => :x => t.kw[:xreduce], :y => :y => t.kw[:yreduce]), t.table)
        else
            single_w = groupby((:xy => t.kw[:xreduce], ), t.table, select = :x)
            a, b = unique(column(single_w, :compare))
            xtable = renamecol(filter(i -> i.compare == a, single_w), :xy, :x)
            ytable = renamecol(filter(i -> i.compare == b, single_w), :xy, :y)
            pkey_tup = (listsplits(t)..., :across)
            g = join(xtable, ytable, lkey = pkey_tup, rkey = pkey_tup,
                lselect = :x, rselect = :y)
        end
    else
        g = groupby(t.table, (listsplits(t)...), select = (:across, :x, :y), flatten = true) do tt
            split_table = table(tt, pkey = :across, presorted = true)
            xaxis = get_axis(columns(split_table, :x), t.kw[:axis_type], t.kw[:compute_axis])
            get_grouped_error(t.kw[:summarize]..., t.kw[:fclosure], xaxis, split_table, t.kw[:compute_error])
        end
    end
    return filter(_isfinite, g)
end