abstract type AbstractSelector; end

struct ColumnSelector{T} <: AbstractSelector
    table::T
    splitby
    compare
    across
    x
    y
    kw::Dict{Symbol, Any}
end

ColumnSelector(df) = ColumnSelector(df, Symbol[], nothing, nothing, nothing, nothing, Dict{Symbol, Any}(:compare => false))

struct Selector{T, F1<:Function, F2<:Function, F3<:Function, F4<:Function, F5<:Function} <: AbstractSelector
    table::T
    splitby::F1
    compare::F2
    across::F3
    x::F4
    y::F5
    kw::Dict{Symbol, Any}
end

Selector(df) = Selector(df, t -> ("y1",), t -> (),t -> 0.0, t -> 0.0, t -> NaN, Dict{Symbol, Any}(:compare => false))

Base.convert(::Type{Selector}, a::Selector) = a
Base.convert(::Type{Selector}, a) = Selector(a)

struct Table2Process{T}
    table::T
    kw::Dict{Symbol, Any}
end

Table2Process(df) = Table2Process(df, Dict{Symbol, Any}())

tuplify(x::Tuple, args...) = (x..., args...)
tuplify(x, args...) = (x, args...)

_get_tup(t) = map(_get, t)

_get(t) = t
_get(t::DataValue) = get(t)

_nafree_tup(t::Tuple) = all(_nafree, t)

_nafree(t) = true
_nafree(t::DataValue) = !isna(t)

function Table2Process(s::Selector)
    enumerable = TableTraits.getiterator(s.table)
    T = eltype(enumerable)
    if s.kw[:compare]
        select_func = t -> tuplify(s.splitby(t), s.compare(t), s.across(t), s.x(t), s.y(t))
    else
        select_func = t -> tuplify(s.splitby(t), s.across(t), s.x(t), s.y(t))
    end
    tuple_vec = map(_get_tup, Iterators.filter(_nafree_tup, (select_func(i) for i in enumerable)))
    Table2Process(columns(convert(Columns, tuple_vec)), s.kw)
end

getcolumn(t::IndexedTables.AbstractIndexedTable, s) = columns(t, s)
getcolumn(t, s) = getindex(t, s)

getlength(t::IndexedTables.AbstractIndexedTable) = length(t)
getlength(t) = size(t, 1)

function Table2Process(s::ColumnSelector)
    if s.splitby == Symbol[]
        splitter = [fill("y1", getlength(s.table))]
    elseif isa(s.splitby, Symbol)
        splitter = [getcolumn(s.table, s.splitby)]
    else
        splitter = map(t -> getcolumn(s.table, t), s.splitby)
    end
    across_col = s.across == nothing ? fill(0.0, getlength(s.table)) : getcolumn(s.table, s.across)
    y_col = s.y == nothing ? fill(NaN, getlength(s.table)) : getcolumn(s.table, s.y)
    x = isa(s.x, Symbol) ? getcolumn(s.table, s.x) : fill(s.x, getlength(s.table))
    if s.compare == nothing
        columns = tuple(splitter..., across_col, x, y_col)
    else
        columns = tuple(splitter..., getcolumn.(s.table, s.compare), across_col, x, y_col)
    end
    Table2Process(columns, s.kw)
end

struct ProcessedTable{T}
    table::T
    kw::Dict{Symbol, Any}
end

ProcessedTable(t::Table2Process) = pipeline(t)
ProcessedTable(s::AbstractSelector) = ProcessedTable(Table2Process(s))

function Base.filter(f::Function, p::ProcessedTable)
    filtered_table = filter(f, p.table)
    ProcessedTable(filtered_table, p.kw)
end

nsplits(t::Union{Table2Process, ProcessedTable}) = count(t -> startswith(t, "s"), string.(colnames(t.table)))
listsplits(t::Union{Table2Process, ProcessedTable}) = [Symbol(:s, i) for i = 1:nsplits(t)]
