[![Checks][checks-badge]][checks-workflow]

<p align="center">
  <img alt="Logo" src="./assets/sphynx-landscape.png" width="80%">
</p>
<p align="center">
  <a href="#cli">CLI</a> •
  <a href="#dotfiles">Dotfiles</a> •
  <a href="#external-tools">External Tools</a> •
  <a href="#workspace-configuration">Workspace Configuration</a>
</p>

## About

This is a personal project containing everything I use on a daily basis and how
I set up my machine. It has aliases, functions, CLI, workspace configuration,
applications' settings, and more.

### CLI

<img align="right" alt="Demo" src="./assets/sphynx-demo.gif" width="60%">

This is the core of Sphynx. The [command-line interface][cli-folder] is used to
automate boring/repetitive tasks and helps me manage the other parts of this
project.

e.g.

```bash
$ sx docker logs
$ sx android device --connect
$ sx system clear-trash
```

Most commands use the [fuzzy finder][fzf] to provide a better experience with an
interactive menu + fuzzy searching.

If you want to give the CLI a try, you can use [Homebrew][homebrew] or
[Linuxbrew][linuxbrew] to install it.

```bash
brew install hpedrorodrigues/tools/sphynx
```

### Dotfiles

All dotfiles are inside the [dotfiles][dotfiles-folder] module. It has common
aliases, functions, and configuration files that I use daily.

#### Shell startup performance

**zsh**

```
♪ sx shell benchmark zsh
ProductName:		macOS
ProductVersion:		26.6.2
BuildVersion:		25G83

> Hyperfine

Benchmark 1: zsh -i -c exit
  Time (mean ± σ):      77.0 ms ±   1.9 ms    [User: 39.9 ms, System: 28.1 ms]
  Range (min … max):    74.8 ms …  82.6 ms    37 runs

> Bench

benchmarking zsh -i -c exit
time                 77.15 ms   (74.90 ms .. 78.24 ms)
                     0.999 R²   (0.998 R² .. 1.000 R²)
mean                 79.17 ms   (78.30 ms .. 81.43 ms)
std dev              2.319 ms   (573.0 μs .. 3.878 ms)

> Time

/usr/bin/time zsh -i -c exit (5x)
        0.07 real         0.04 user         0.02 sys
        0.07 real         0.03 user         0.02 sys
        0.07 real         0.03 user         0.02 sys
        0.07 real         0.03 user         0.02 sys
        0.07 real         0.03 user         0.02 sys
```

**bash**

```
♪ sx shell benchmark bash
ProductName:		macOS
ProductVersion:		26.6.2
BuildVersion:		25G83

> Hyperfine

Benchmark 1: bash -i -c exit
  Time (mean ± σ):      84.1 ms ±   1.9 ms    [User: 43.9 ms, System: 32.3 ms]
  Range (min … max):    82.2 ms …  90.9 ms    33 runs

> Bench

benchmarking bash -i -c exit
time                 86.27 ms   (84.74 ms .. 90.17 ms)
                     0.997 R²   (0.989 R² .. 1.000 R²)
mean                 86.85 ms   (85.82 ms .. 88.70 ms)
std dev              2.294 ms   (1.155 ms .. 3.799 ms)

> Time

/usr/bin/time bash -i -c exit (5x)
        0.08 real         0.04 user         0.03 sys
        0.08 real         0.04 user         0.03 sys
        0.08 real         0.04 user         0.03 sys
        0.08 real         0.04 user         0.03 sys
        0.08 real         0.04 user         0.03 sys
```

### External tools

[External tools][external-tools] are tools that you don't want to install
on your machine but you'd like to use them.

They are basically shell functions calling Docker behind the scenes. Every
function runs a published image, either one under `ghcr.io/hpedrorodrigues` or
a vendor image (e.g. Kafka).

### Workspace configuration

I use [Ansible][ansible-website] to configure my machine. It automates tedious
tasks [installing packages and applications][playbooks-folder] that I use almost
daily.

[cli-folder]: ./modules/cli
[fzf]: https://github.com/junegunn/fzf
[homebrew]: https://brew.sh
[linuxbrew]: https://docs.brew.sh/Homebrew-on-Linux
[dotfiles-folder]: ./modules/dotfiles
[external-tools]: ./modules/dotfiles/common/scripts/external_tools.sh
[ansible-website]: https://www.ansible.com
[playbooks-folder]: ./modules/playbooks
[checks-badge]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/checks.yml/badge.svg
[checks-workflow]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/checks.yml
