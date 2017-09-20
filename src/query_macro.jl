# Copied from Query.jl to simplify the creation of anonymous functions

function helper_replace_anon_func_syntax(ex)
	if !(isa(ex, Expr) && ex.head==:->)
		new_symb = gensym()
		new_ex = MacroTools.postwalk(ex) do x
			if isa(x, Symbol) && x==:_
				return new_symb
			else
				return x
			end
		end
		return :($new_symb -> $(new_ex) )
	else
		return ex
	end
end

function replace_selector(s::Selector, f, sym::Symbol)
    fields = fieldnames(s)
    new_fields = Tuple(field == sym ? f : getfield(s, field) for field in fields)
    Selector(new_fields...)
end

macro splitby(s, arg)
    anon_func = helper_replace_anon_func_syntax(arg)
    Expr(:call, :_splitby, esc(s), esc(anon_func))
end

_splitby(s::Selector, f) = replace_selector(s, f, :splitby)

macro across(s, arg)
    p = (arg == Expr(:quote, :all)) ? Expr(:quote, :all) :
        helper_replace_anon_func_syntax(arg)
    Expr(:call, :_across, esc(s), esc(p))
end

function _across(s::Selector, f)
    if f == :all
        s.kw[:acrossall] = true
        s2 = s
    else
        s2 = replace_selector(s, f, :across)
    end
    s2.kw[:compute_error] = :across
    s2
end

macro x(s, x, args...)
    anon_func = helper_replace_anon_func_syntax(x)
    Expr(:call, :_x, esc(s), esc(anon_func), (esc(arg) for arg in args)...)
end

function _x(s::Selector, f, args...)
    s2 = replace_selector(s, f, :x)
    kws = [:axis_type, :nbins]
    for (ind, val) in enumerate(args)
        s2.kw[kws[ind]] = val
    end
    return s2
end

_kw(ex) = Expr(:kw, ex.args...)

store_kws(; kwargs...) = kwargs

macro y(s, y, args...)
    if @capture(y, :(sym_))
        p = y
    else
        p = helper_replace_anon_func_syntax(y)
    end
    Expr(:call, :_y, esc(s), esc(p), (esc(_kw(arg)) for arg in args)...)
end

function _y(s::Selector, f; kwargs...)
    if isa(f, Symbol)
        s2 = s
        s2.kw[:f] = f
    else
        s2 = replace_selector(s, f, :y)
        s2.kw[:f] = :locreg
    end
    s2.kw[:fkwargs] = store_kws(; kwargs...)
    return s2
end

macro summarize(s, trend, variation)
    Expr(:call, :_summarize, esc(s), esc(trend), esc(variation))
end

function _summarize(s::Selector, trend, variation)
    s.kw[:summarize] = (trend, variation)
    return s
end

for f in (:_splitby, :_across, :_x, :_y, :summarize)
    @eval ($f)(s, args...; kwargs...) = ($f)(convert(Selector, s), args...; kwargs...)
end
