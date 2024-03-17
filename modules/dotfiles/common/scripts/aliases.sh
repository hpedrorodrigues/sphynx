#!/usr/bin/env bash

# Reload the shell (e.g. invoke as a login shell)
alias reload='exec ${SHELL} -l'

# Rerun the last command with sudo
alias please='sudo $(fc -ln -1)'

# Allow aliases to be "sudoed".
# http://www.gnu.org/software/bash/manual/bashref.html#Aliases
#
# If the last character of the alias value is a blank, then the next command
# word following the alias is also checked for alias expansion.
alias sudo='sudo '
alias watch='watch '

# Shortcut to list files
alias l='ls -lash'

# Shortcut for Docker and Docker Compose
alias d='docker'
alias dc='docker compose'

# Empty the trash
alias empty-trash='sx system clear-trash'

# Docker
alias dd='sx docker delete'
alias ds='sx docker ls'
alias dl='sx docker logs'
alias di='sx docker inspect'
alias dex='sx docker exec'

# TMUX
alias ts='sx terminal tmux ls'
alias tn='sx terminal tmux new'
alias ta='sx terminal tmux attach'
alias tk='sx terminal tmux kill'
alias tka='sx terminal tmux kill-all'
alias tfa='sx terminal tmux force-attach'

# Clipboard
alias pbcopy='sx system clipboard copy'
alias pbpaste='sx system clipboard paste'

# Git & Github
alias g='git'
alias gs='git status'

alias gch='sx git check'
alias gbc='sx git branch --clear'
alias gbs='sx git branch --switch'

alias gpr='sx git pull_request preview'

alias gd='sx git diff'

alias email='sx github email'

# Kubernetes
alias k='kubectl'
alias sk='kubectl --namespace kube-system'
alias pk='kubectl --namespace kube-public'

# e.g. kx pods.spec
# e.g. kx deploy.spec.template.spec
alias kx='kubectl explain'
alias kxr='kubectl explain --recursive'

# Kubernetes API Query
# e.g. kq /apis
# e.g. kq /healthz/etcd
# e.g. kq /logs/kube-apiserver.log
# e.g. kq /apis/metrics.k8s.io/v1beta1/nodes
alias kq='kubectl get --raw'

alias kk='kubectl krew'

alias ks='sx kubernetes ls'
alias kd='sx kubernetes describe'
alias ke='sx kubernetes edit'
alias kex='sx kubernetes exec'
alias kg='sx kubernetes get'
alias kl='sx kubernetes logs'
alias kns='sx kubernetes namespace'
alias ktx='sx kubernetes context'
alias krs='sx kubernetes rollout status'
alias krr='sx kubernetes rollout restart'
alias krh='sx kubernetes rollout history'
alias kpf='sx kubernetes port-forward'
alias kto='sx kubernetes topology'
alias kdb='sx kubernetes debug --image=ghcr.io/hpedrorodrigues/debug'

alias ktc='kubectl top pods --sort-by=cpu --all-namespaces --use-protocol-buffers'
alias ktm='kubectl top pods --sort-by=memory --all-namespaces --use-protocol-buffers'

# Flux

alias fxs='flux get all'

# Terraform

alias tfm='terraform fmt -recursive'

# Network
alias dns='sx system dns'
alias flush='sx system dns --flush'

alias cert='sx security certificate --print'
alias certsans='sx security certificate --print-sans'

alias public_ip='sx system ip --public'
alias private_ip='sx system ip --private'
alias gateway_ip='sx system ip --gateway'
