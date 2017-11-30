abstract type AbstractSelector; end

struct ColumnSelector{T, S1<:Union{Symbol, Vector{Symbol}}, S2<:Union{Symbol, Void},
    S3<:Union{Symbol, Void}, S4<:Union{Symbol, Void}, S5<:Union{Symbol, Void}} <: AbstractSelector
    table::T
    splitby::S1
    compare::S2
    across::S3
    x::S4
    y::S5
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

function Table2Process(s::Selector)
    enumerable = TableTraits.getiterator(s.table)
    T = eltype(enumerable)
    if s.kw[:compare]
        select_func = t -> tuplify(s.splitby(t), s.compare(t), s.across(t), s.x(t), s.y(t))
    else
        select_func = t -> tuplify(s.splitby(t), s.across(t), s.x(t), s.y(t))
    end
    column_types = Base._return_type(select_func, Tuple{T,}).parameters
    columns = Tuple(_type(S)[] for S in column_types)
    fill_cols!(columns, enumerable, select_func)
    Table2Process(columns, s.kw)
end

getcolumn(t::IndexedTables.AbstractIndexedTable, s) = columns(t, s)
getcolumn(t, s) = getindex(t, s)

getlength(t::IndexedTables.AbstractIndexedTable) = length(t)
getlength(t) = size(t, 1)

function Table2Process(s::ColumnSelector)
    if s.splitby == Symbol[]
        splitter = [fill("y1", size(s.table, 1))]
    elseif isa(s.splitby, Symbol)
        splitter = [getcolumn(s.table, s.splitby)]
    else
        splitter = getcolumn.(s.table, s.splitby)
    end
    across_col = s.across == nothing ? fill(0.0, getlength(s.table)) : getcolumn(s.table, s.across)
    y_col = s.y == nothing? fill(NaN, getlength(s.table)) : getcolumn(s.table, s.y)
    if s.compare == nothing
        columns = tuple(splitter..., across_col, getcolumn(s.table, s.x), y_col)
    else
        columns = tuple(splitter..., getcolumn.(s.table, s.compare), across_col, getcolumn(s.table, s.x), y_col)
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

_isnull(x) = false
_isnull(x::DataValue) = isnull(x)

_get(x) = x
_get(x::DataValue) = get(x)

_type(x) = x
_type(x::Type{DataValue{T}}) where T = T


@generated function fill_cols!(columns, enumerable, select_func)
    push_exprs = Expr(:block)
    for i in find(collect(columns.types) .!= Void)
        ex = quote
            push!(columns[$i], _get(j[$i]))
        end
        push!(push_exprs.args, ex)
    end
    cond_push_exprs = quote
        j = select_func(i)
        if !any(_isnull, j)
            $push_exprs
        end
    end

    quote
        for i in enumerable
            $cond_push_exprs
        end
    end
end
