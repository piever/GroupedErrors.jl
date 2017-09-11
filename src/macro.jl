macro given(a,b)
    esc(helper(a, b))
end

store_kws(; kwargs...) = kwargs

function helper(a, b)
    i = a.args[2]
    df = a.args[3]
    args = b.args
    kwargs = []
    fkwargs = []
    f1 = :(t -> true)
    groupfs = Any[0.0]
    acrossf = 0.0
    xf = 0.0
    yf = NaN
    for arg in args
        if @capture(arg, fun_(cond_)) && fun == :where
            f1 = Expr(:->, i, cond)
        elseif @capture(arg, fun_(as__)) && fun == :groupby
            groupfs = as
        elseif @capture(arg, fun_(var_)) && fun == :across
            if var == Expr(:quote, :all)
                push!(kwargs, Expr(:kw, :acrossall, true))
            else
                acrossf = var
            end
            push!(kwargs, Expr(:kw, :compute_error, Expr(:quote, :across)))
        elseif @capture(arg, fun_(var_, others__)) && fun == :x
            xf = var
            kws = [:axis_type, :nbins]
            for (ind, val) in enumerate(others)
                push!(kwargs, Expr(:kw, kws[ind], val))
            end
        elseif @capture(arg, fun_(var_, others__)) && fun == :y
            if @capture(var, :(sym_))
                push!(kwargs, Expr(:kw, :f, var))
            else
                push!(kwargs, Expr(:kw, :f, Expr(:quote, :locreg)))
                yf = var
            end
            fkwargs = others
        elseif @capture(arg, fun_(as__)) && fun == :summarize
            push!(kwargs, Expr(:kw, :summarize, Expr(:tuple, as...)))
        end
    end

    f2 = Expr(:->, i, Expr(:tuple, groupfs..., acrossf, xf, yf))
    selector =  Expr(:call, :(GroupedErrors.Selector), f1, f2)
    plottable_table = Expr(:call, :(GroupedErrors.group_apply),
        :(GroupedErrors.get_cols($df, $selector)),
        kwargs..., Expr(:kw, :fkwargs, Expr(:call, :(GroupedErrors.store_kws), fkwargs...)))
    if @capture(args[end], fun_(as__; kws__)) && fun != :y
        return Expr(:call, :(GroupedErrors.plot_helper), plottable_table, fun, as..., kws...)
    elseif @capture(args[end], fun_(as__)) && fun != :y
        return Expr(:call, :(GroupedErrors.plot_helper), plottable_table, fun, as...)
    else
        return plottable_table
    end
end

function plot_helper(t::Table2Process, f::Function, args...; kwargs...)
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
