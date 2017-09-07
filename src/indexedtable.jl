function RecipesBase.plot(s::IndexedTable; kwargs...)
    plt = RecipesBase.plot()
    RecipesBase.plot!(plt, s; kwargs...)
    return plt
end

function RecipesBase.plot!(plt::Plots.Plot, s::IndexedTable; kwargs...)
    series_ind = findfirst(t -> t[1] == :seriestype, kwargs)
    series = series_ind == 0 ? :path : kwargs[series_ind][2]
    x = s.index.columns[end]
    y = isa(s.data, Columns) ? s.data.columns[1] : s.data
    group = s.index.columns[1:end-1]
    err = (isa(s.data, Columns) && (length(s.data.columns) > 1)) ? s.data.columns[2] : nothing
    if series == :scatter
        RecipesBase.plot!(plt, x, y; group = group, err = err, kwargs...)
    elseif series == :bar
        if group == ()
            RecipesBase.plot!(plt, x, y; group = group, err = err, kwargs...)
        else
            RecipesBase.plot!(plt, StatPlots.GroupedBar((x, y)); group = group, err = err, kwargs...)
        end
    else
        RecipesBase.plot!(plt, x, y; group = group, ribbon = err, kwargs...)
    end
end
