# Benchmark of Julia Threads for "trivially parallel" problem

See https://discourse.julialang.org/t/scaling-of-threads-for-trivially-parallel-problem/92949/1

**Note**: The parallelization scaling issue was resolved by reducing the number of allocations. The original benchmark results are in the [old version of this README](https://github.com/goerz-testing/2023-01_rotating_tai_benchmark/blob/597a93ddc58b7e4cb92e6c8d3900f4776ddf748b/README.md#benchmark-of-julia-threads-for-trivially-parallel-problem).

```
julia --project="." -e 'using Pkg; Pkg.instantiate()'
julia --project="." -t 1 benchmark.jl
julia --project="." -t 2 benchmark.jl
julia --project="." -t 4 benchmark.jl
julia --project="." -t 8 benchmark.jl
```

## System information

```
:> uname -a
Linux 5.10.0-8-amd64 #1 SMP Debian 5.10.46-2 (2021-07-20) x86_64 GNU/Linux

:> julia --version
julia version 1.8.0

:> cpuinfo
Intel(R) processor family information utility, Version 2019 Update 8 Build 20200624 (id: 4f16ad915)
Copyright (C) 2005-2020 Intel Corporation.  All rights reserved.

=====  Processor composition  =====
Processor name    : Intel(R) Core(TM) i9-9900
Packages(sockets) : 1
Cores             : 8
Processors(CPUs)  : 16
Cores per package : 8
Threads per core  : 2

=====  Processor identification  =====
Processor       Thread Id.      Core Id.        Package Id.
0               0               0               0
1               0               1               0
2               0               2               0
3               0               3               0
4               0               4               0
5               0               5               0
6               0               6               0
7               0               7               0
8               1               0               0
9               1               1               0
10              1               2               0
11              1               3               0
12              1               4               0
13              1               5               0
14              1               6               0
15              1               7               0
=====  Placement on packages  =====
Package Id.     Core Id.        Processors
0               0,1,2,3,4,5,6,7         (0,8)(1,9)(2,10)(3,11)(4,12)(5,13)(6,14)(7,15)

=====  Cache sharing  =====
Cache   Size            Processors
L1      32  KB          (0,8)(1,9)(2,10)(3,11)(4,12)(5,13)(6,14)(7,15)
L2      256 KB          (0,8)(1,9)(2,10)(3,11)(4,12)(5,13)(6,14)(7,15)
L3      16  MB          (0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15)
```

## Benchmark result

### Original code

Relevant benchmarked code (`benchmark.jl`):

```
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
```

Note: compared to the [original issue](https://discourse.julialang.org/t/scaling-of-threads-for-trivially-parallel-problem/92949/1), `N` and `M` were set to 16 to avoid unequal workloads for different threads.

```
:> JULIA_EXCLUSIVE=1 julia --project=. -t 1 benchmark.jl
  0.208167 seconds (33.80 k allocations: 1.917 MiB)
  2.751524 seconds (3.60 M allocations: 144.673 MiB, 0.75% gc time, 0.07% compilation time)
120.464164 seconds (100.59 M allocations: 4.076 GiB, 0.33% gc time, 0.03% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark.jl
  0.207674 seconds (33.80 k allocations: 1.917 MiB)
  2.714671 seconds (3.60 M allocations: 144.673 MiB, 0.72% gc time, 0.06% compilation time)
 94.199065 seconds (100.59 M allocations: 4.076 GiB, 0.26% gc time, 0.05% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark.jl
  0.211552 seconds (33.80 k allocations: 1.917 MiB)
  2.811510 seconds (3.60 M allocations: 144.673 MiB, 0.70% gc time, 0.05% compilation time)
 80.154506 seconds (100.59 M allocations: 4.076 GiB, 0.37% gc time, 0.06% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark.jl
  0.210447 seconds (33.80 k allocations: 1.917 MiB)
  2.786815 seconds (3.60 M allocations: 144.673 MiB, 0.70% gc time, 0.05% compilation time)
 66.755464 seconds (100.59 M allocations: 4.076 GiB, 0.68% gc time, 0.07% compilation time)
```


### Equal workload

In `benchmark2.jl`:

```
potential_depth_values = fill(1.1MHz, 16)
separation_time_values = fill(100μs, 16)
```

This means that every call to `propagate_splitting` does the same exact thing, so all threads should have the exact same workload.

```
:> JULIA_EXCLUSIVE=1 julia --project=. -t 1 benchmark2.jl
  0.210143 seconds (33.80 k allocations: 1.917 MiB)
  0.221251 seconds (33.88 k allocations: 1.922 MiB, 1.29% compilation time)
 54.201312 seconds (8.73 M allocations: 494.694 MiB, 0.10% gc time, 0.07% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark2.jl
  0.212420 seconds (33.80 k allocations: 1.917 MiB)
  0.225637 seconds (33.88 k allocations: 1.922 MiB, 1.24% compilation time)
 27.806800 seconds (8.73 M allocations: 494.716 MiB, 0.24% gc time, 0.17% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark2.jl
  0.213204 seconds (33.80 k allocations: 1.917 MiB)
  0.215185 seconds (33.88 k allocations: 1.922 MiB, 1.33% compilation time)
 14.431739 seconds (8.73 M allocations: 494.777 MiB, 0.41% gc time, 0.34% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark2.jl
  0.207609 seconds (33.80 k allocations: 1.917 MiB)
  0.212293 seconds (33.88 k allocations: 1.922 MiB, 1.33% compilation time)
  8.424910 seconds (8.73 M allocations: 494.711 MiB, 0.48% compilation time)
```

### Refactoring: t_r outside of inner loop

Relevant code from `benchmark3.jl`, cf. https://discourse.julialang.org/t/scaling-of-threads-for-trivially-parallel-problem/92949/5:

```
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
```


```
:> JULIA_EXCLUSIVE=1 julia --project=. -t 1 benchmark3.jl
  0.206196 seconds (33.80 k allocations: 1.917 MiB)
  0.209529 seconds (33.88 k allocations: 1.922 MiB, 1.35% compilation time)
 53.185182 seconds (8.72 M allocations: 494.140 MiB, 0.10% gc time, 0.07% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark3.jl
  0.208810 seconds (33.80 k allocations: 1.917 MiB)
  0.212513 seconds (33.88 k allocations: 1.922 MiB, 1.31% compilation time)
 27.373068 seconds (8.72 M allocations: 494.182 MiB, 0.16% gc time, 0.17% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark3.jl
  0.211508 seconds (33.80 k allocations: 1.917 MiB)
  0.213555 seconds (33.88 k allocations: 1.922 MiB, 1.53% compilation time)
 14.384025 seconds (8.72 M allocations: 494.191 MiB, 0.34% gc time, 0.32% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark3.jl
  0.212579 seconds (33.80 k allocations: 1.917 MiB)
  0.216517 seconds (33.88 k allocations: 1.922 MiB, 1.35% compilation time)
  8.450139 seconds (8.72 M allocations: 494.156 MiB, 0.45% compilation time)
```

### Refactoring: "false sharing"

Use a vector of vectors instead of a matrix. In `benchmark4.jl`:

```
function map_fidelity(potential_depth_values, separation_time_values; kwargs...)
    N = length(potential_depth_values)
    M = length(separation_time_values)
    F = Vector{Vector{Float64}}(undef, M)

    Threads.@threads for j in 1:M
        @inbounds t_r = separation_time_values[j]
        F_j = zeros(N)
        @inbounds for i in 1:N
            V0 = potential_depth_values[i]
            F_j[i] = propagate_splitting(t_r, V0; kwargs...)
        end
        F[j] = F_j
    end
    return vcat(F...)

end
```

```
:> JULIA_EXCLUSIVE=1 julia --project=. -t 1 benchmark4.jl
  0.204621 seconds (33.80 k allocations: 1.917 MiB)
  0.210162 seconds (33.88 k allocations: 1.922 MiB, 1.38% compilation time)
 53.749415 seconds (8.79 M allocations: 498.078 MiB, 0.14% gc time, 0.12% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark4.jl
  0.211242 seconds (33.80 k allocations: 1.917 MiB)
  0.215194 seconds (33.88 k allocations: 1.922 MiB, 1.33% compilation time)
 27.770841 seconds (8.79 M allocations: 498.106 MiB, 0.29% gc time, 0.26% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark4.jl
  0.211822 seconds (33.80 k allocations: 1.917 MiB)
  0.213592 seconds (33.88 k allocations: 1.922 MiB, 1.35% compilation time)
 14.596262 seconds (8.79 M allocations: 498.086 MiB, 0.30% gc time, 0.45% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark4.jl
  0.209312 seconds (33.80 k allocations: 1.917 MiB)
  0.212435 seconds (33.88 k allocations: 1.922 MiB, 1.36% compilation time)
  8.479042 seconds (8.79 M allocations: 498.104 MiB, 0.29% gc time, 1.08% compilation time)
```

### Sleeping

Replace the `propagate_splitting` function with something trivial:

```
function propagate_splitting(
        separation_time,
        potential_depth;
        kwargs...
    )
    sleep(0.6)
    return rand()
end
```

```
:> JULIA_EXCLUSIVE=1 julia --project=. -t 1 benchmark5.jl
  0.601209 seconds (7 allocations: 176 bytes)
  0.604624 seconds (90 allocations: 5.031 KiB, 0.44% compilation time)
154.104534 seconds (73.22 k allocations: 3.763 MiB, 0.02% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark5.jl
  0.602025 seconds (7 allocations: 176 bytes)
  0.604489 seconds (90 allocations: 5.031 KiB, 0.44% compilation time)
 77.081345 seconds (73.25 k allocations: 3.765 MiB, 0.05% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark5.jl
  0.602031 seconds (7 allocations: 176 bytes)
  0.604647 seconds (90 allocations: 5.031 KiB, 0.46% compilation time)
 38.565316 seconds (73.31 k allocations: 3.768 MiB, 0.09% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark5.jl
  0.601987 seconds (7 allocations: 176 bytes)
  0.604643 seconds (90 allocations: 5.031 KiB, 0.46% compilation time)
 19.299850 seconds (73.42 k allocations: 3.775 MiB, 0.19% compilation time)
```

### Multi-process parallelization

This solves the problem with `@distributed`. From `benchmark_distributed_driver.jl`:

```
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
```

Note that some overhead here is expected due to the `vcat` reduction.

```
:> julia -p1 benchmark_distributed_driver.jl
      From worker 2:      Activating project at `~/2023-01_rotating_tai_benchmark`
  Activating project at `~/2023-01_rotating_tai_benchmark`
  0.206928 seconds (33.80 k allocations: 1.917 MiB)
  0.209682 seconds (33.88 k allocations: 1.922 MiB, 1.31% compilation time)
 59.544753 seconds (2.71 M allocations: 179.497 MiB, 0.07% gc time, 1.15% compilation time: 1% of which was recompilation)

:> julia -p2 benchmark_distributed_driver.jl
      From worker 3:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 2:      Activating project at `~/2023-01_rotating_tai_benchmark`
  Activating project at `~/2023-01_rotating_tai_benchmark`
  0.232625 seconds (33.80 k allocations: 1.917 MiB, 9.91% gc time)
  0.211565 seconds (33.88 k allocations: 1.922 MiB, 1.33% compilation time)
 34.113498 seconds (2.71 M allocations: 179.529 MiB, 0.05% gc time, 2.00% compilation time: 1% of which was recompilation)

:> julia -p4 benchmark_distributed_driver.jl
      From worker 4:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 2:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 3:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 5:      Activating project at `~/2023-01_rotating_tai_benchmark`
  Activating project at `~/2023-01_rotating_tai_benchmark`
  0.209870 seconds (33.80 k allocations: 1.917 MiB)
  0.213252 seconds (33.88 k allocations: 1.922 MiB, 1.33% compilation time)
 21.967531 seconds (2.71 M allocations: 179.590 MiB, 0.08% gc time, 3.15% compilation time: 1% of which was recompilation)

:> julia -p8 benchmark_distributed_driver.jl
      From worker 9:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 4:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 2:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 8:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 7:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 5:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 6:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 3:      Activating project at `~/2023-01_rotating_tai_benchmark`
  Activating project at `~/2023-01_rotating_tai_benchmark`
  0.210575 seconds (33.80 k allocations: 1.917 MiB)
  0.212953 seconds (33.88 k allocations: 1.922 MiB, 1.35% compilation time)
 18.250584 seconds (2.71 M allocations: 179.729 MiB, 0.20% gc time, 4.08% compilation time: 1% of which was recompilation)
```

### Better runtime distribution

Going back to the [original computation](#original-code), the different calls to `propagate_splitting` have different runtime. Since the runtime is mostly proportional to the separation time, this put all the long runtimes in one thread and all the short runtimes in another. We can remedy this by transposing the construction of the fidelity matrix:

```
function map_fidelity(potential_depth_values, separation_time_values; kwargs...)
    N = length(potential_depth_values)
    M = length(separation_time_values)
    F = zeros(M, N)
    Threads.@threads for i = 1:N
        @inbounds V0 = potential_depth_values[i]
        @inbounds for j = 1:M
            t_r = separation_time_values[j]
            F[j, i] = propagate_splitting(t_r, V0; kwargs...)
        end
    end
    return transpose(F)
end
```

```
:> JULIA_EXCLUSIVE=1 julia --project=. -t 1 benchmark6.jl
  0.208736 seconds (33.80 k allocations: 1.917 MiB)
  2.796440 seconds (3.60 M allocations: 144.673 MiB, 0.74% gc time, 0.06% compilation time)
120.989621 seconds (100.59 M allocations: 4.077 GiB, 0.34% gc time, 0.04% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark6.jl
  0.213141 seconds (33.80 k allocations: 1.917 MiB)
  2.789801 seconds (3.60 M allocations: 144.673 MiB, 0.70% gc time, 0.05% compilation time)
 61.719640 seconds (100.59 M allocations: 4.077 GiB, 0.74% gc time, 0.07% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark6.jl
  0.210999 seconds (33.80 k allocations: 1.917 MiB)
  2.777318 seconds (3.60 M allocations: 144.673 MiB, 0.76% gc time, 0.05% compilation time)
 33.486723 seconds (100.59 M allocations: 4.077 GiB, 1.53% gc time, 0.12% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark6.jl
  0.210624 seconds (33.80 k allocations: 1.917 MiB)
  2.793085 seconds (3.60 M allocations: 144.673 MiB, 0.95% gc time, 0.06% compilation time)
 19.351503 seconds (100.59 M allocations: 4.077 GiB, 3.05% gc time, 0.22% compilation time)
```
