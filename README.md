[![Checks (Stable)][stable-checks-badge]][stable-checks-workflow]
[![Build and Push (Stable)][stable-build-badge]][stable-build-workflow]

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
applications' settings, docker images, and more.

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
ProductName:            macOS
ProductVersion:         14.0

> Hyperfine

Benchmark 1: zsh -i -c exit
  Time (mean ± σ):      57.2 ms ±   0.5 ms    [User: 31.2 ms, System: 22.2 ms]
  Range (min … max):    56.0 ms …  58.5 ms    50 runs

> Bench

benchmarking zsh -i -c exit
time                 57.97 ms   (57.61 ms .. 58.59 ms)
                     1.000 R²   (0.999 R² .. 1.000 R²)
mean                 57.96 ms   (57.78 ms .. 58.31 ms)
std dev              430.2 μs   (251.9 μs .. 635.6 μs)

> Time

/usr/bin/time zsh -i -c exit (5x)
        0.06 real         0.03 user         0.02 sys
        0.06 real         0.03 user         0.02 sys
        0.05 real         0.03 user         0.02 sys
        0.05 real         0.03 user         0.02 sys
        0.05 real         0.03 user         0.02 sys
```

**bash**
```
♪ sx shell benchmark bash
ProductName:            macOS
ProductVersion:         14.0

> Hyperfine

Benchmark 1: bash -i -c exit
  Time (mean ± σ):      40.5 ms ±   1.1 ms    [User: 19.1 ms, System: 20.1 ms]
  Range (min … max):    39.2 ms …  45.2 ms    69 runs

> Bench

benchmarking bash -i -c exit
time                 41.15 ms   (40.94 ms .. 41.48 ms)
                     1.000 R²   (1.000 R² .. 1.000 R²)
mean                 41.00 ms   (40.95 ms .. 41.18 ms)
std dev              155.3 μs   (46.41 μs .. 291.6 μs)

> Time

/usr/bin/time bash -i -c exit (5x)
        0.04 real         0.01 user         0.01 sys
        0.04 real         0.01 user         0.02 sys
        0.03 real         0.01 user         0.01 sys
        0.03 real         0.01 user         0.01 sys
        0.04 real         0.01 user         0.02 sys
```

### External tools

[External tools][external-tools] are tools that you don't want to install
on your machine but you'd like to use them.

They are basically shell functions calling Docker behind the scenes, but
not all functions use the dockerfiles available in this project
(e.g. Kafka and Zookeeper).

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

[stable-checks-badge]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-checks.yml/badge.svg
[stable-checks-workflow]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-checks.yml

[stable-build-badge]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-build.yml/badge.svg
[stable-build-workflow]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-build.yml
