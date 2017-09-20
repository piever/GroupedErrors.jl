using DataFrames, RDatasets, IndexedTables, IterableTables, StatPlots
school = RDatasets.dataset("mlmRev","Hsb82")

s = Selector(school, t -> (t.MAch > 10,), t -> 1, t -> 1, t -> 1, Dict{Symbol, Any}())

using Lazy
using Query
@> school begin
    #@where (_.Minrty == "No")
    @splitby (_.Sx, _.Minrty)
    @across _.School
    @x(_.SSS, :continuous)
    @y(:density, bandwidth = 0.1)
    @plot plot()
end

@plot t plot()
typeof(t.table[4])
pipeline!(t.table, t.kw)

plot

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

using DataFrames, Query, IndexedTables
df = DataFrame(name=["John", "Sally", "Kirk"], age=[23., 42., 59.], children=[3,5,2])
using NamedTuples
using Query
const ToT =
ToT((1 for i in 1:2)...)::ToT
typeof(@NT(a=2))
const Tr = NamedTuples.make_tuple([:a, :b]){DataValues.DataValue{Int64},DataValues.DataValue{Int64}}

buildf(T) = i -> T((i.children for j in 1:2)...)::T

TuT = NamedTuples.make_tuple([:a, :b]){Int64, Int64}

buildf()(@NT(children = 124))
fs(i)::Tr =

fff(@NT(children = 124))
ff(i) = map(j -> i.children, (1,2))
ss = tuple([:children]...)
ss
gettype(ss) =
    Base._return_type(i -> map(s -> getfield(i, s), ss),
    Tuple{typeof(@NT(children = 124)),})

gettype(ss)
NamedTuples.make_tuple([:a, :b]){Tuple{Int64, Int64}.parameters...}


map(s -> i.s, (:children,))
x = df |>
    @where(_.age>40) |>
    @select(i -> fs(i))
const L = NamedTuples.make_tuple(
    [:a, :b]){DataValues.DataValue{Int64},DataValues.DataValue{Int64}}
@select(df, i -> @NT(a = i.children))
it = Query.select(Query.query(df), i -> NamedTuples.make_tuple(
    [:a, :b]){DataValues.DataValue{Int64},DataValues.DataValue{Int64}}(
    (i.children, i.children)...)::L, :(1+1))
f = i -> NamedTuples.make_tuple(
    [:a, :b]){DataValues.DataValue{Int64},DataValues.DataValue{Int64}}(
    (i.children, i.children)...)
T = Base._return_type(i -> NamedTuples.make_tuple(
    [:a, :b]){DataValues.DataValue{Int64},DataValues.DataValue{Int64}}(
    (i.children, i.children)...)::L, Tuple{typeof(@NT(children = 124)),})
l = Query.EnumerableSelect{T, typeof(Query.query(df)), typeof(f)}(
    Query.query(df),f)

TableTraitsUtils.create_columns_from_iterabletable(l)
for t in TableTraitsUtils.getiterator(x)
    println(t[1])
end

EnumerableSelect{T,S,Q}(source, f)

TableTraits.isiterable(x)
methods(DataFrame)

df |> @groupby(_.a)
