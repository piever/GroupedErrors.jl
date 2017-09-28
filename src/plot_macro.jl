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
    group = s.index.columns[1:end-1]
    group_list = unique(Columns(group...))
    plot_kwargs = [(plot_kwarg[1], reshape(plot_kwarg[2].(group_list), 1, :))
        for plot_kwarg in t.kw[:plot_kwargs]]
    if axis_type == :pointbypoint
        err_kwargs = []
        if eltype(s.data.columns[1])<:Tuple
            x = getindex.(s.data.columns[1], 1)
            push!(err_kwargs, (:xerr, getindex.(s.data.columns[1], 2)))
        else
            x = s.data.columns[1]
        end
        if eltype(s.data.columns[2])<:Tuple
            y = getindex.(s.data.columns[2], 1)
            push!(err_kwargs, (:yerr, getindex.(s.data.columns[2], 2)))
        else
            y = s.data.columns[2]
        end
        f(args..., x, y; group = group, err_kwargs...,kwargs..., plot_kwargs...)
    else
        x = s.index.columns[end]
        y = isa(s.data, Columns) ? s.data.columns[1] : s.data
        err = (isa(s.data, Columns) && (length(s.data.columns) > 1)) ? s.data.columns[2] : nothing
        (axis_type == :continuous) && (err_style = :ribbon)
        f(args..., x, y; group = group, (err_style, err), kwargs..., plot_kwargs...)
    end
end

plot_helper(t, f::Function, err_style, args...; kwargs...) =
    plot_helper(ProcessedTable(t), f, err_style, args...; kwargs...)
