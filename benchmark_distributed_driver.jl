@everywhere using Pkg
@everywhere Pkg.activate(".")
@everywhere include("benchmark_distributed.jl")

@everywhere potential_depth_values = fill(1.1MHz, 16)
@everywhere separation_time_values = fill(100μs, 16)

propagate_splitting(separation_time_values[1], potential_depth_values[1])
@time propagate_splitting(separation_time_values[1], potential_depth_values[1])
@time propagate_splitting(separation_time_values[end], potential_depth_values[end])


function map_fidelity(potential_depth_values, separation_time_values; kwargs...)
    N = length(potential_depth_values)
    M = length(separation_time_values)

    F = @sync @distributed (vcat) for j in 1:M
        t_r = separation_time_values[j]
        F_j = zeros(N)
        for i in 1:N
            V0 = potential_depth_values[i]
            F_j[i] = propagate_splitting(t_r, V0; kwargs...)
        end
        F_j
    end

end

@time F = map_fidelity(potential_depth_values, separation_time_values)
