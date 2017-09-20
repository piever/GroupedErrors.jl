macro plot(plottable_table, plot_call)
    if @capture(plot_call, fun_(as__; kws__))
        return esc(Expr(:call, :(GroupedErrors.plot_helper), plottable_table, fun, as..., kws...))
    elseif @capture(plot_call, fun_(as__))
        return esc(Expr(:call, :(GroupedErrors.plot_helper), plottable_table, fun, as...))
    else
        return esc(plottable_table)
    end
end

function plot_helper(t::ProcessedTable, f::Function, args...; kwargs...)
    s = t.table
    axis_type = t.kw[:axis_type]
    if axis_type == :pointbypoint
        x = s.data.columns[1]
        y = s.data.columns[2]
        group = s.index.columns
        f(args..., x, y; group = group, kwargs...)
    else
        x = s.index.columns[end]
        y = isa(s.data, Columns) ? s.data.columns[1] : s.data
        group = s.index.columns[1:end-1]
        err = (isa(s.data, Columns) && (length(s.data.columns) > 1)) ? s.data.columns[2] : nothing
        err_style = axis_type == :discrete ? :err : :ribbon
        f(args..., x, y; group = group, (err_style, err), kwargs...)
    end
end

plot_helper(t, f::Function, args...; kwargs...) =
    plot_helper(ProcessedTable(t), f, args...; kwargs...)
