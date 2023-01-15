# Benchmark of Julia Threads for "trivially parallel" problem

See https://discourse.julialang.org/t/scaling-of-threads-for-trivially-parallel-problem/92949/1

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
  0.621074 seconds (1.13 M allocations: 1.605 GiB, 10.51% gc time)
  3.164572 seconds (4.70 M allocations: 1.745 GiB, 1.30% gc time, 0.05% compilation time)
218.653798 seconds (382.22 M allocations: 414.555 GiB, 3.55% gc time, 0.03% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark.jl
  0.634131 seconds (1.13 M allocations: 1.605 GiB, 9.40% gc time)
  3.179692 seconds (4.70 M allocations: 1.745 GiB, 1.41% gc time, 0.05% compilation time)
161.966233 seconds (393.42 M allocations: 414.873 GiB, 4.29% gc time, 0.05% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark.jl
  0.634875 seconds (1.13 M allocations: 1.605 GiB, 10.65% gc time)
  3.158805 seconds (4.70 M allocations: 1.745 GiB, 1.43% gc time, 0.05% compilation time)
150.478485 seconds (419.44 M allocations: 415.518 GiB, 3.84% gc time, 0.06% compilation time)

:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark.jl
  0.637444 seconds (1.13 M allocations: 1.605 GiB, 10.64% gc time)
  3.157171 seconds (4.70 M allocations: 1.745 GiB, 1.62% gc time, 0.05% compilation time)
148.714731 seconds (459.50 M allocations: 416.672 GiB, 3.43% gc time, 0.06% compilation time)
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
  0.629423 seconds (1.13 M allocations: 1.605 GiB, 9.97% gc time)
  0.593253 seconds (1.13 M allocations: 1.605 GiB, 4.79% gc time, 0.47% compilation time)
153.666410 seconds (290.36 M allocations: 410.962 GiB, 5.05% gc time, 0.04% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark2.jl
  0.633268 seconds (1.13 M allocations: 1.605 GiB, 9.65% gc time)
  0.596045 seconds (1.13 M allocations: 1.605 GiB, 4.71% gc time, 0.49% compilation time)
 98.435518 seconds (309.35 M allocations: 411.444 GiB, 6.31% gc time, 0.08% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark2.jl
  0.644217 seconds (1.13 M allocations: 1.605 GiB, 9.94% gc time)
  0.625575 seconds (1.13 M allocations: 1.605 GiB, 6.09% gc time, 0.46% compilation time)
 99.298586 seconds (333.82 M allocations: 412.088 GiB, 5.35% gc time, 0.08% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark2.jl
  0.639156 seconds (1.13 M allocations: 1.605 GiB, 10.09% gc time)
  0.618517 seconds (1.13 M allocations: 1.605 GiB, 6.23% gc time, 0.47% compilation time)
121.498563 seconds (374.74 M allocations: 413.286 GiB, 3.96% gc time, 0.07% compilation time)
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
  0.637919 seconds (1.13 M allocations: 1.605 GiB, 10.09% gc time)
  0.616912 seconds (1.13 M allocations: 1.605 GiB, 5.80% gc time, 0.46% compilation time)
155.916642 seconds (290.35 M allocations: 410.961 GiB, 5.63% gc time, 0.04% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark3.jl
  0.649860 seconds (1.13 M allocations: 1.605 GiB, 9.97% gc time)
  0.619335 seconds (1.13 M allocations: 1.605 GiB, 5.39% gc time, 0.46% compilation time)
101.228960 seconds (310.37 M allocations: 411.469 GiB, 6.39% gc time, 0.08% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark3.jl
  0.647611 seconds (1.13 M allocations: 1.605 GiB, 10.04% gc time)
  0.626761 seconds (1.13 M allocations: 1.605 GiB, 6.26% gc time, 0.46% compilation time)
 98.742242 seconds (333.60 M allocations: 412.081 GiB, 5.43% gc time, 0.08% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark3.jl
  0.630414 seconds (1.13 M allocations: 1.605 GiB, 7.85% gc time)
  0.613773 seconds (1.13 M allocations: 1.605 GiB, 4.99% gc time, 0.46% compilation time)
119.975070 seconds (374.90 M allocations: 413.286 GiB, 3.85% gc time, 0.07% compilation time)
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
  0.634388 seconds (1.13 M allocations: 1.605 GiB, 10.14% gc time)
  0.619022 seconds (1.13 M allocations: 1.605 GiB, 6.21% gc time, 0.47% compilation time)
156.127696 seconds (290.42 M allocations: 410.965 GiB, 5.66% gc time, 0.06% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark4.jl
  0.639602 seconds (1.13 M allocations: 1.605 GiB, 10.56% gc time)
  0.606554 seconds (1.13 M allocations: 1.605 GiB, 5.80% gc time, 0.48% compilation time)
 98.933797 seconds (305.89 M allocations: 411.390 GiB, 6.50% gc time, 0.11% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark4.jl
  0.637588 seconds (1.13 M allocations: 1.605 GiB, 9.29% gc time)
  0.612409 seconds (1.13 M allocations: 1.605 GiB, 5.37% gc time, 0.47% compilation time)
 98.618285 seconds (333.16 M allocations: 412.074 GiB, 5.18% gc time, 0.11% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark4.jl
  0.637485 seconds (1.13 M allocations: 1.605 GiB, 8.71% gc time)
  0.622894 seconds (1.13 M allocations: 1.605 GiB, 5.53% gc time, 0.49% compilation time)
121.259312 seconds (373.66 M allocations: 413.257 GiB, 3.95% gc time, 0.09% compilation time)
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
  0.601872 seconds (7 allocations: 176 bytes)
  0.604645 seconds (90 allocations: 5.031 KiB, 0.46% compilation time)
154.111709 seconds (73.22 k allocations: 3.763 MiB, 0.02% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 2 benchmark5.jl
  0.601741 seconds (7 allocations: 176 bytes)
  0.604557 seconds (90 allocations: 5.031 KiB, 0.45% compilation time)
 77.088923 seconds (73.25 k allocations: 3.765 MiB, 0.05% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 4 benchmark5.jl
  0.601994 seconds (7 allocations: 176 bytes)
  0.604744 seconds (90 allocations: 5.031 KiB, 0.45% compilation time)
 38.558808 seconds (73.31 k allocations: 3.768 MiB, 0.09% compilation time)
:> JULIA_EXCLUSIVE=1 julia --project=. -t 8 benchmark5.jl
  0.601660 seconds (7 allocations: 176 bytes)
  0.604487 seconds (90 allocations: 5.031 KiB, 0.45% compilation time)
 19.300890 seconds (73.41 k allocations: 3.775 MiB, 0.19% compilation time)
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
  0.659220 seconds (1.13 M allocations: 1.605 GiB, 10.05% gc time)
  0.623259 seconds (1.13 M allocations: 1.605 GiB, 6.04% gc time, 0.45% compilation time)
159.409128 seconds (2.71 M allocations: 179.434 MiB, 0.01% gc time, 0.42% compilation time: 1% of which was recompilation)

:> julia -p2 benchmark_distributed_driver.jl
      From worker 3:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 2:      Activating project at `~/2023-01_rotating_tai_benchmark`
  Activating project at `~/2023-01_rotating_tai_benchmark`
  0.665675 seconds (1.13 M allocations: 1.605 GiB, 10.35% gc time)
  0.631846 seconds (1.13 M allocations: 1.605 GiB, 6.31% gc time, 0.45% compilation time)
 91.579614 seconds (2.71 M allocations: 179.529 MiB, 0.02% gc time, 0.75% compilation time: 1% of which was recompilation)

:> julia -p4 benchmark_distributed_driver.jl
      From worker 3:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 2:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 4:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 5:      Activating project at `~/2023-01_rotating_tai_benchmark`
  Activating project at `~/2023-01_rotating_tai_benchmark`
  0.667681 seconds (1.13 M allocations: 1.605 GiB, 10.48% gc time)
  0.623414 seconds (1.13 M allocations: 1.605 GiB, 6.34% gc time, 0.45% compilation time)
 56.961555 seconds (2.71 M allocations: 179.590 MiB, 0.04% gc time, 1.23% compilation time: 1% of which was recompilation)

:> julia -p8 benchmark_distributed_driver.jl
      From worker 6:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 3:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 5:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 2:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 7:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 4:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 8:      Activating project at `~/2023-01_rotating_tai_benchmark`
      From worker 9:      Activating project at `~/2023-01_rotating_tai_benchmark`
  Activating project at `~/2023-01_rotating_tai_benchmark`
  0.640059 seconds (1.13 M allocations: 1.605 GiB, 9.37% gc time)
  0.625552 seconds (1.13 M allocations: 1.605 GiB, 6.69% gc time, 0.44% compilation time)
 48.310770 seconds (2.71 M allocations: 179.714 MiB, 0.04% gc time, 1.51% compilation time: 1% of which was recompilation)
```
