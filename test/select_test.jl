using DataFrames, RDatasets, IndexedTables, IterableTables, StatPlots
school = RDatasets.dataset("mlmRev","Hsb82")


using Lazy
using Query
@> school begin
    #@where (_.Minrty == "No")
    #@splitby (_.Minrty,)
    @compare _.Minrty
    @across _.Sx
    @xy _.SSS
    #@y _.MAch
    @plot scatter()
end

Plots.abline!(1,0)

using IndexedTables
s = IndexedTable(rand(Bool, 20), rand(Bool, 20))
t = IndexedTable([true, false], [true, false])
innerjoin(s, t)
vv = (x,y) -> x+y

vv(1,2)

df = DataFrame(x=rand(10))
using IterableTables
df::IterableTables.IterableTable
using KernelDensity
using StatPlots
v = randn(100)
plot([v], [v, v],
    seriestype = [:histogram :path],
    layout = (2,1),
    nbins = 40,
    legend = false,
    xlims = (-5, 5))
histogram(rand(1000), randn(1000))

marginalhist(randn(1000), randn(1000))
s = kde([vcat(rand(500),rand(500)-5)  randn(1000)])
    plot(s)

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

s = @from i in school begin
    @where i.Minrty == "Yes"
    @groupby i by i.Sx into j
    @select {j..MAch, j..School, } into k
    @let shared_axis = compute_axis(k..MAch)
    @group k.MAch by k.School into l
    @select {axis = compute_axis(l), density = compute_density(l, axis) } into m
    @group m by m.axis into n
    @select {mean(m..density), sem(m..density)}
    @collect DataFrame
end

using IndexedTables

s = IndexedTable(rand(Bool,100), fill(true,100), rand(100))
mapslices(t->IndexedTable([1, 2], [1, 2]) , s, [])

s = IndexedTable(rand(Bool,100), rand(Bool,100),  rand(100))
mapslices(t->IndexedTable([1, 2], [1, 2]) , s,  [])
IndexedTables.mapslices(println, s, [1])

IndexedTables.mapslices(t -> IndexedTable(rand(2), rand(2)), s, [1])
# TO DO: kws for plot call + locreg bug
s = IndexedTable(rand(Bool,10), rand(10))


using Query, DataFrames


x = @from i in df begin
    @where i.age>40
    @select (i.name,)#merge(i, @NT(b=2))
    @collect
end

using Query, DataFrames

df = DataFrame(a=[1,1,2,3], b=[4,5,6,8])

df2 = df |>
    @groupby({a = (_.a, _.a)} ) |>
    @select({a = _.key, b=_}) |>
    DataFrame
