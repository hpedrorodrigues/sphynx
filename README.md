<p align="center">
  <img src="./assets/sphynx-landscape.png" align="center" height="50%" width="50%"/>
</p>

[![Checks (Stable)][stable-checks-badge]][stable-checks-workflow]
[![Build and Push (Stable)][stable-build-badge]][stable-build-workflow]

Sphynx is a personal project including CLI, dotfiles, workspace setup scripts
among other things.

<img align="right" src="./assets/sphynx-demo.gif" width="60%" />

- [About](#about)
  - [CLI](#cli)
  - [Dotfiles](#dotfiles)
  - [Alien scripts](#alien-scripts)
  - [Workspace configuration](#workspace-configuration)
- [Installation](#installation)

## About

Sphynx has aliases, functions, CLI, workspace setup configuration,
applications' settings, docker images. Everything I use on a daily
basis and how I set up my machine.

It's divided into four main components described below.

### CLI

Sphynx provides a [command-line interface][cli-folder] to handle all stuff related to
this project and to automate boring tasks using [docopt][docopt-website].

e.g.
```bash
$ sx docker logs
$ sx android device --connect
$ sx system clear-trash
```

The commands are configured using environment variables, and each command may
have its own settings. For instance, `sx kubernetes ls` uses the env var
`SX_KUBERNETES_RESOURCES` to know what resources to list.

Most commands use the [fuzzy finder][fzf] to provide a better experience with an
interactive menu + fuzzy searching, and even though it's not a mandatory
dependency it could be good installing it.

### Dotfiles

All dotfiles are inside the [dotfiles][dotfiles-folder] directory. It has common
aliases, functions, and configuration files that I use daily.

**Ok, but how about shell startup performance?**

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

### Alien scripts

[Alien commands][alien-commands] are tools that you don't want to install
on your machine but you'd like to use them.

They are basically shell functions calling Docker behind the scenes, but
not all functions use the dockerfiles available in this project
(e.g. Kafka and Zookeeper).

### Workspace configuration

[Ansible][ansible-website] playbooks are recipes that configures and install tools
on my machine.

It automates tedious tasks installing packages and applications that I use
almost daily.

## Installation

If you want to give the CLI a try, you can use [Homebrew][homebrew] or
[Linuxbrew][linuxbrew] to install it.

```bash
brew install hpedrorodrigues/tools/sphynx
```

But if you want to give this whole project a try, it's recommended you fork
this repository and adjust it to your needs! Be careful!


[cli-folder]: ./modules/cli
[dotfiles-folder]: ./modules/dotfiles
[playbooks-folder]: ./modules/playbooks
[alien-folder]: ./modules/images
[alien-commands]: ./modules/dotfiles/common/scripts/alien.sh

[ansible-website]: https://www.ansible.com
[docopt-website]: http://docopt.org
[dotbot-website]: https://github.com/anishathalye/dotbot

[fzf]: https://github.com/junegunn/fzf

[stable-checks-badge]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-checks.yml/badge.svg
[stable-checks-workflow]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-checks.yml

[stable-build-badge]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-build.yml/badge.svg
[stable-build-workflow]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-build.yml

[homebrew]: https://brew.sh
[linuxbrew]: https://docs.brew.sh/Homebrew-on-Linux
