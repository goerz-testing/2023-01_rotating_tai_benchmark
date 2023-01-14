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
