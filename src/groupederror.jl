function get_groupederror(trend, variation, f!, xaxis, xtable, t, ce; kwargs...)
    if get_symbol(ce) != :bootstrap
        splitdata = mapslices(tt -> f!(xaxis, xtable, select(tt,2); kwargs...), t, 2)
    else
        ns = ce[2]
        ref_data = select(t,2)
        large_table = IndexedTable(repeat(collect(1:ns), inner = length(xaxis)),
            repeat(collect(xaxis), outer = ns), zeros(ns*length(xaxis)), presorted = true)
        splitdata = mapslices(large_table, 1) do tt
            nd = length(ref_data.data)
            perm = rand(1:nd,nd)
            permuted_data = IndexedTable(keys(ref_data,1)[rand(1:nd,nd)], ref_data.data[rand(1:nd,nd)])
            f!(xaxis, xtable, permuted_data; kwargs...)
        end
    end
    nanfree = filter(isfinite, splitdata)
    if get_symbol(ce) == :none
        return reducedim((x,y)->y, nanfree, 1)
    else
        return reducedim_vec(i -> (trend(i), variation(i)), nanfree, 1)
    end
end
