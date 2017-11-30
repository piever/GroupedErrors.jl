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

function replace_selector(s::S, f, sym::Symbol) where {S<:AbstractSelector}
    fields = fieldnames(s)
    new_fields = Tuple(field == sym ? f : getfield(s, field) for field in fields)
	(S <: Selector) ? Selector(new_fields...) : ColumnSelector(new_fields...)
end

macro splitby(s, arg)
    anon_func = helper_replace_anon_func_syntax(arg)
    Expr(:call, :_splitby, esc(s), esc(anon_func))
end

_splitby(s::AbstractSelector, f) = replace_selector(s, f, :splitby)

macro across(s, arg)
    p = (arg == Expr(:quote, :all)) ? Expr(:quote, :all) :
        helper_replace_anon_func_syntax(arg)
    Expr(:call, :_across, esc(s), esc(p))
end

function _across(s::AbstractSelector, f)
    if f == :all
        s.kw[:acrossall] = true
        s2 = s
    else
        s2 = replace_selector(s, f, :across)
    end
	haskey(s2.kw, :compute_error) && isa(s2.kw[:compute_error], Number) &&
		error("@bootstrap and @across are not supported in the same pipeline")
    s2.kw[:compute_error] = :across
	s2.kw[:xreduce] = get(s2.kw, :xreduce, mean)
    s2.kw[:yreduce] = get(s2.kw, :yreduce, mean)
    s2
end

macro bootstrap(s, arg = 1000)
    Expr(:call, :_bootstrap, esc(s), esc(arg))
end

function _bootstrap(s::AbstractSelector, n)
	haskey(s.kw, :compute_error) && s.kw[:compute_error] == :across &&
		error("@bootstrap and @across are not supported in the same pipeline")
    s.kw[:compute_error] = n
	s
end

functionize(f) = f
functionize(f::Tuple) = x -> map(g->g(x), f)

macro x(s, x, args...)
    anon_func = helper_replace_anon_func_syntax(x)
    Expr(:call, :_x, esc(s), esc(anon_func), (esc(arg) for arg in args)...)
end

function _x(s::AbstractSelector, f, args...)
    s2 = replace_selector(s, f, :x)
    kws = [:axis_type, :nbins]
	if args == () || isa(args[1], Symbol)
	    for (ind, val) in enumerate(args)
	        s2.kw[kws[ind]] = val
	    end
	else
		s2.kw[:xreduce] = functionize(args[1])
	end
    return s2
end


macro xlims(s, arg)
    p = helper_replace_anon_func_syntax(arg)
    Expr(:call, :_xlims, esc(s), esc(p))
end

_xlims(s, p) = _xlims(ProcessedTable(s), p)
function _xlims(s::ProcessedTable, p)
    filter(s) do i
        lower, upper = p(i)
        x = i.x isa Tuple ? i.x[1] : i.x
        lower <= x <= upper
    end
end

macro ylims(s, arg)
    p = helper_replace_anon_func_syntax(arg)
    Expr(:call, :_ylims, esc(s), esc(p))
end

_ylims(s, p) = _ylims(ProcessedTable(s), p)
function _ylims(s::ProcessedTable, p)
    filter(s) do i
        lower, upper = p(i)
        y = i.y isa Tuple ? i.y[1] : i.y
        lower <= y <= upper
    end
end

_kw(ex) = (isa(ex, Expr) && ex.head == :(=)) ? Expr(:kw, ex.args...) : ex

store_kws(; kwargs...) = kwargs

macro y(s, y, args...)
    if @capture(y, :(sym_))
        p = y
    else
        p = helper_replace_anon_func_syntax(y)
    end
    Expr(:call, :_y, esc(s), esc(p), (esc(_kw(arg)) for arg in args)...)
end

function _y(s::Selector, f, args...; kwargs...)
    if isa(f, Symbol)
        s2 = s
		s2.kw[:f] = f == :custom ? args[1] : f
    else
        s2 = replace_selector(s, f, :y)
        s2.kw[:f] = :locreg
		s2.kw[:axis_type] = get(s2.kw, :axis_type, :pointbypoint)
		(length(args) > 0) && (s2.kw[:yreduce] = functionize(args[1]))
    end
    s2.kw[:fkwargs] = store_kws(; kwargs...)
    return s2
end

function _y(s::ColumnSelector, f, args...; kwargs...)
    if get(s.kw, :axis_type, :pointbypoint) != :pointbypoint
		s2 = (f == :locreg) ? replace_selector(s, args[1], :y) : s
		s2.kw[:f] = f
    else
		s2 = replace_selector(s, f, :y)
		s2.kw[:f] = :locreg
		s2.kw[:axis_type] = get(s2.kw, :axis_type, :pointbypoint)
		(length(args) > 0) && (s2.kw[:yreduce] = functionize(args[1]))
    end
    s2.kw[:fkwargs] = store_kws(; kwargs...)
    return s2
end

macro xy(s, arg)
	return esc(:(GroupedErrors.@y(GroupedErrors.@x($s, $arg), $arg)))
end

macro xy(s, arg, f)
	return esc(:(GroupedErrors.@y(GroupedErrors.@x($s, $arg, $f), $arg, $f)))
end

macro compare(s, f)
	anon_func = helper_replace_anon_func_syntax(f)
	Expr(:call, :_compare, esc(s), esc(anon_func))
end

function _compare(s::AbstractSelector, f)
	s2 = replace_selector(s, f, :compare)
	s2.kw[:compare] = true
	s2
end

macro summarize(s, trend, variation)
    Expr(:call, :_summarize, esc(s), esc(trend), esc(variation))
end

function _summarize(s::AbstractSelector, trend, variation)
    s.kw[:summarize] = (trend, variation)
    return s
end

macro set_attr(s, arg, f)
    func = helper_replace_anon_func_syntax(f)
    Expr(:call, :_set_attr, esc(s), esc(arg), esc(func))
end

function _set_attr(s::AbstractSelector, arg, f)
    s.kw[:plot_kwargs] = get(s.kw, :plot_kwargs, [])
    push!(s.kw[:plot_kwargs], (arg, f))
	s
end

for f in (:_splitby, :_across, :_bootstrap, :_x, :_y, :_summarize, :_compare, :_set_attr)
    @eval ($f)(s, args...; kwargs...) = ($f)(convert(Selector, s), args...; kwargs...)
end
