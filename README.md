# sddp-lab
Laboratório para análise em pequena escala de variações no problema de planejamento energético usando SDDP.


## Uso

```
$ julia

]activate .
Ctrl+D

$ julia --project main.jl
```


## Instalação como pacote

É possível realizar a instalação do pacote a partir do repositório privado, mesmo sem adicioná-lo a um registro privado.

Tendo instalada uma versão de Julia `>=1.7`, desde que esteja configurada a CLI do `git` local com as credenciais necessárias para se acessar o repositório, basta fazer, utilizando autenticação via `ssh`:

```bash
export JULIA_PKG_USE_CLI_GIT=true
julia
]
add git@github.com:rjmalves/sddp-lab.git
```

No caso de uso em sistema operacional Windows, pode-se fazer algo semelhante, por exemplo no `PowerShell`:

```powershell
$env:JULIA_PKG_USE_CLI_GIT=true
julia
]
add git@github.com:rjmalves/sddp-lab.git
```