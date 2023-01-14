# # Map adiabaticity

# ## Hamiltonian

using QuantumPropagators
using LinearAlgebra
using FFTW
using Serialization

using Revise

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

includet("./rotating_tai.jl")

includet("./split_propagator.jl")

function rotating_tai_hamiltonian(;
    tlist,
    θ,
    ω,  # function of time
    V₀,
    Ω=0.0,
    direction=1,
    m=N_SITES,
    mass=EFFECTIVE_MASS
)

    V = Diagonal(V₀ .* cos.(m .* θ))

    dθ = θ[2] - θ[1]
    nθ = length(θ)
    pgrid::Vector{Float64} = 2π * fftfreq(nθ, 1 / dθ)
    P::Diagonal{Float64, Vector{Float64}} = Diagonal(pgrid)
    K::Diagonal{Float64, Vector{Float64}} = Diagonal(pgrid .^ 2 / (2 * mass))

    _Ψ = Array{ComplexF64}(undef, nθ)
    fft_op = plan_fft!(_Ψ)
    ifft_op = plan_ifft!(_Ψ)
    transforms = (Ψ -> fft_op * Ψ, Ψ -> ifft_op * Ψ)

    K′::Diagonal{Float64, Vector{Float64}} = K - Ω * P

    if ω isa Number
        if direction == 1
            H = SplitGenerator(K′ + ω * P, V, transforms...)
        elseif direction == -1
            H = SplitGenerator(K′ - ω * P, V, transforms...)
        else
            error("direction must be ±1")
        end
    else
        if direction == 1
            H = SplitGenerator(hamiltonian(K′, (P, ω)), V, transforms...)
        elseif direction == -1
            H = SplitGenerator(hamiltonian(K′, (-P, ω)), V, transforms...)
        else
            error("direction must be ±1")
        end
    end
end

omega_ramp_up(t; w0=OMEGA_TARGET, t_r) = w0 * sin(π * t / (2t_r))^2;

using QuantumPropagators.Controls: discretize_on_midpoints

function choose_timesteps(separation_time; timesteps_per_microsec=1, minimum_timesteps=1001)
    return max(
        minimum_timesteps,
        Int(separation_time ÷ μs) * timesteps_per_microsec + 1
    )
end


function propagate_splitting(
        separation_time,
        potential_depth;
        ret=:fidelity,
        timesteps_per_microsec=1,
        minimum_timesteps=1001,
        theta_max=0.25π,
        theta_steps=1024,
        kwargs...
    )
    nt = choose_timesteps(separation_time; timesteps_per_microsec, minimum_timesteps)
    tlist = collect(range(0, separation_time, length=nt))
    ω_func(t) = omega_ramp_up(t; w0=OMEGA_TARGET, t_r=separation_time)
    θ::Vector{Float64} = collect(range(0, theta_max, length=theta_steps))
    Ĥ = rotating_tai_hamiltonian(
        tlist=tlist,
        V₀=potential_depth,
        θ=θ,
        ω=discretize_on_midpoints(ω_func, tlist)
    )
    if ret == :system
        return Ĥ, tlist
    end
    Ĥ₀ = evaluate(Ĥ, tlist, 1)
    Ψ₀ = get_ground_state(Ĥ₀, θ, π/8,  d=0.05, steps=10_000)
    if ret == :initial_state
        return Ψ₀, θ
    end
    Ĥ_tgt = evaluate(Ĥ, tlist, nt-1)
    Ψ_tgt = get_ground_state(Ĥ_tgt, θ, π/8,  d=0.05, steps=10_000)
    if ret == :target
        return Ψ_tgt, θ
    end
    Ψ = propagate(
        Ψ₀,
        Ĥ,
        tlist;
        method=:splitprop,
        kwargs...
    )
    if ret == :propagation
        return Ψ
    end
    F = abs2(Ψ ⋅ Ψ_tgt)
    if ret == :fidelity
        return F
    else
        error("Invalid ret=$ret")
    end
end

# ## Map

potential_depth_values = collect(range(0.1MHz, 2.2MHz, length=16))
separation_time_orders_of_magnitude = collect(range(-1, 5, length=16))
separation_time_values = [10^x * μs for x in separation_time_orders_of_magnitude]

propagate_splitting(separation_time_values[1], potential_depth_values[1])
@time propagate_splitting(separation_time_values[1], potential_depth_values[1])
@time propagate_splitting(separation_time_values[end], potential_depth_values[end])

function map_fidelity(potential_depth_values, separation_time_values; kwargs...)
    N = length(potential_depth_values)
    M = length(separation_time_values)
    F = zeros(N, M)
    @inbounds Threads.@threads for j = 1:M
        @inbounds for i = 1:N
            t_r = separation_time_values[j]
            V0 = potential_depth_values[i]
            F[i, j] = propagate_splitting(t_r, V0; kwargs...)
        end
    end
    return F
end

@time map_fidelity(potential_depth_values, separation_time_values)
