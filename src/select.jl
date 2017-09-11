struct Selector{F1<:Function, F2<:Function}
    f1::F1
    f2::F2
end

function get_cols(df, s::Selector)
    enumerable = TableTraits.getiterator(df)
    T = eltype(enumerable)
    column_types = Base._return_type(s.f2, Tuple{T,}).parameters
    columns = Tuple(S[] for S in column_types)
    fill_cols!(columns, enumerable, s::Selector)
    Tuple(convert_missing.(t) for t in columns)
end

@generated function fill_cols!(columns, enumerable, s::Selector)
    push_exprs = Expr(:block)
    for i in find(collect(columns.types) .!= Void)
        ex = quote
            j = s.f2(i)
            push!(columns[$i], j[$i])
        end
        push!(push_exprs.args, ex)
    end
    cond_push_exprs = quote
        if s.f1(i)
            $push_exprs
        end
    end

    quote
        for i in enumerable
            $cond_push_exprs
        end
    end
end

convert_missing(el) = el
convert_missing(el::DataValue{T}) where {T} = get(el, error("Missing data of type $T is not supported"))
convert_missing(el::DataValue{<:AbstractString}) = get(el, "")
convert_missing(el::DataValue{Symbol}) = get(el, Symbol())
convert_missing(el::DataValue{<:Real}) = get(convert(DataValue{Float64}, el), NaN)
