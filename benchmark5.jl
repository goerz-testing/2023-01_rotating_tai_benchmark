# # Map adiabaticity

# ## Hamiltonian

using QuantumPropagators
using LinearAlgebra
using FFTW
using Serialization
using Random

const 𝕚 = 1im;
const μm = 1;
const μs = 1;
const ns = 1e-3μs;
const cm = 1e4μm;
const met = 1e6μm;
const sec = 1e6μs;
const ms = 1e3μs;
const MHz = 2π;
const Dalton = 1.5746097504353806e+01;

const RUBIDIUM_MASS = 86.91Dalton;
const TAI_RADIUS = 42μm
const N_SITES = 8;
const OMEGA_TARGET = 10π / sec;
const EFFECTIVE_MASS = TAI_RADIUS^2 * RUBIDIUM_MASS;


function propagate_splitting(
        separation_time,
        potential_depth;
        kwargs...
    )
    sleep(0.6)
    return rand()
end

# ## Map

potential_depth_values = fill(1.1MHz, 16)
separation_time_values = fill(100μs, 16)

propagate_splitting(separation_time_values[1], potential_depth_values[1])
@time propagate_splitting(separation_time_values[1], potential_depth_values[1])
@time propagate_splitting(separation_time_values[end], potential_depth_values[end])

function map_fidelity(potential_depth_values, separation_time_values; kwargs...)
    N = length(potential_depth_values)
    M = length(separation_time_values)
    F = zeros(N, M)

    Threads.@threads for j in eachindex(separation_time_values)
        @inbounds t_r = separation_time_values[j]
        @inbounds for i in eachindex(potential_depth_values)
            V0 = potential_depth_values[i]
            F[i, j] = propagate_splitting(t_r, V0; kwargs...)
        end
    end

end

@time map_fidelity(potential_depth_values, separation_time_values)
