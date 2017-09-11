using DataFrames, RDatasets, IndexedTables, IterableTables
school = RDatasets.dataset("mlmRev","Hsb82")
kw = Dict{Symbol,Any}(:f => :density, :axis_type => :binned)
table = IndexedTable(Columns(school[:Sx], school[:School], school[:SSS]),
    fill(NaN, size(school,1)))

s = group_apply(table, f = :density,
    axis_type = :binned, nbins = 20)
s
using Plots
#plot(s)
ee(::Any, e) = 2
ee(1,2)
f(x,y,z) = y +z
Val{:discrete}()::Val{:discrete}
g = (args...) -> f(1, args...)
g(2,3)

:Protocol in [1, 2]


s = @given i in school begin
    where(i.Minrty == "Yes")
    groupby(i.Sx)
    #xsummarize(mean)
    #ysummarize(std)
    across(i.School)
    x(i.MAch)
    y(:density)
    scatter()
end




using StatPlots
s = @given i in school begin
    #where(i.Minrty == "Yes")
    groupby(i.Minrty)
    #summarize(mean, sem)
    across(i.School)
    x(i.Sx, :continuous)
    y(i.SSS)
    groupedbar(linewidth = 2, color = ["blue" "black"])
end


# TO DO: kws for plot call + locreg bug

#GroupedErrors.plot_helper(s, plot)

s = IndexedTable(Columns(fill(1,10), rand(Bool,10)), Columns(rand(10), rand(10)))
select(aggregate_vec(v -> (mean(t->t[1], v), mean(t->t[2], v)), s),[1]...)


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
        acrossf = var
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
    :(GroupedErrors.IndexedTable(GroupedErrors.get_cols($df, $selector)...)),
    kwargs..., Expr(:kw, :fkwargs, Expr(:call, :(GroupedErrors.store_kws), fkwargs...)))


if @capture(args[end], fun_(as__; kws__)) && fun != :y
    return Expr(:call, plottable_table, :(GroupedErrors.plot_helper), as...; kws...)
else
    return plottable_table
end


args[end].head
@capture(b.args[end], fun_(as__))# && fun != :y
