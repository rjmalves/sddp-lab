# sddp-lab
Laboratório para análise em pequena escala de variações no problema de planejamento energético usando SDDP.


## Uso

```
$ julia

]activate .
Ctrl+D

$ julia --project main.jl
```


## Compilação
$ julia

]activate .

using PackageCompiler
create_sysimage(sysimage_path="sddp-lab.so", precompile_execution_file="main.jl")


$ julia --sysimage "sddp-lab.so" --project  main.jl
