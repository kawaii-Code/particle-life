# Perfomance

Compiled with `odin run . -o:aggressive`

Base: drops to 20 fps on 1000 particles

Soa: almost no improvement, 20 fps on 1100 particles

Convert n^2 to n^2/2: 3x faster, 20 fps on 3000 particles

Space partitioning: Basic grid: 2x faster, 6500 particles

Add Thread Pool: Basic grid: Rendering became the bottleneck, 17000 particles

Finishing touches: The smalles changes make the biggest difference. 40000 particles

