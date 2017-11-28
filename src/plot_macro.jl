macro plot(plottable_table, plot_call = :(plot()), err_style = :(:yerr))
    if @capture(plot_call, fun_(as__; kws__))
        return esc(Expr(:call, :(GroupedErrors.plot_helper), plottable_table, fun, err_style, as..., kws...))
    elseif @capture(plot_call, fun_(as__))
        return esc(Expr(:call, :(GroupedErrors.plot_helper), plottable_table, fun, err_style, as...))
    else
        return esc(plottable_table)
    end
end

function plot_helper(t::ProcessedTable, f::Function, err_style, args...; kwargs...)
    s = t.table
    axis_type = t.kw[:axis_type]
    group = Tuple(columns(t.table, s) for s in listsplits(t))
    group_list = unique(Columns(group...))
    plot_kwargs = [(plot_kwarg[1], reshape(plot_kwarg[2].(group_list), 1, :))
        for plot_kwarg in t.kw[:plot_kwargs]]
    if axis_type == :pointbypoint
        err_kwargs = []
        if eltype(columns(s, :x))<:Tuple
            x = getindex.(columns(s, :x), 1)
            push!(err_kwargs, (:xerr, getindex.(columns(s, :x), 2)))
        else
            x = columns(s, :x)
        end
        if eltype(columns(s, :y))<:Tuple
            y = getindex.(columns(s, :y), 1)
            push!(err_kwargs, (:yerr, getindex.(columns(s, :y), 2)))
        else
            y = columns(s, :y)
        end
        f(args..., x, y; group = group, err_kwargs...,kwargs..., plot_kwargs...)
    else
        x, y = columns(s, :x), columns(s, :y)
        err = :err in colnames(s) ? columns(s, :err) : nothing
        (axis_type == :continuous) && (err_style = :ribbon)
        f(args..., x, y; group = group, (err_style, err), kwargs..., plot_kwargs...)
    end
end

plot_helper(t, f::Function, err_style, args...; kwargs...) =
    plot_helper(ProcessedTable(t), f, err_style, args...; kwargs...)
