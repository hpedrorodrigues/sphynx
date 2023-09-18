<p align="center">
  <img src="./assets/sphynx-landscape.png" align="center" height="50%" width="50%"/>
</p>

[![Checks (Stable)][stable-checks-badge]][stable-checks-workflow]
[![Build and Push (Stable)][stable-build-badge]][stable-build-workflow]

Sphynx is a personal project including CLI, dotfiles, workspace setup scripts
among other things.

<img align="right" src="./assets/sphynx-demo.gif" width="60%" />

# Summary

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
> Hyperfine

Benchmark 1: zsh -i -c exit
  Time (mean ± σ):     121.2 ms ±   4.1 ms    [User: 55.9 ms, System: 48.5 ms]
  Range (min … max):   117.4 ms … 134.2 ms    23 runs

> Bench

benchmarking zsh -i -c exit
time                 132.8 ms   (131.5 ms .. 134.6 ms)
                     1.000 R²   (0.999 R² .. 1.000 R²)
mean                 132.1 ms   (131.6 ms .. 132.8 ms)
std dev              974.4 μs   (483.2 μs .. 1.488 ms)
variance introduced by outliers: 11% (moderately inflated)

> Time

/usr/bin/time zsh -i -c exit (5x)
        0.13 real         0.05 user         0.06 sys
        0.12 real         0.05 user         0.04 sys
        0.12 real         0.05 user         0.04 sys
        0.12 real         0.05 user         0.04 sys
        0.13 real         0.05 user         0.05 sys
```

**bash**
```
♪ sx shell benchmark bash
> Hyperfine

Benchmark 1: bash -i -c exit
  Time (mean ± σ):      97.2 ms ±   1.6 ms    [User: 40.3 ms, System: 49.2 ms]
  Range (min … max):    94.6 ms … 100.7 ms    28 runs

> Bench

benchmarking bash -i -c exit
time                 107.7 ms   (106.6 ms .. 108.7 ms)
                     1.000 R²   (1.000 R² .. 1.000 R²)
mean                 108.8 ms   (108.1 ms .. 110.5 ms)
std dev              1.694 ms   (919.8 μs .. 2.447 ms)

> Time

/usr/bin/time bash -i -c exit (5x)
        0.09 real         0.03 user         0.04 sys
        0.09 real         0.03 user         0.04 sys
        0.09 real         0.03 user         0.04 sys
        0.09 real         0.03 user         0.04 sys
        0.09 real         0.03 user         0.04 sys
```

In order to set up your dotfiles, I recommend using [dotly][dotly] which
is a framework with this purpose.

**Inspiration**:

- [denisidoro/dotfiles](https://github.com/denisidoro/dotfiles)
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles)
- [jessfraz/dotfiles](https://github.com/jessfraz/dotfiles)

Also, [Github ❤ ~/][dotfiles-website] and
[Everything I know - Dotfiles][dotfiles-website2] are your friends.

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


[cli-folder]: ./../cli
[dotfiles-folder]: ./../dotfiles
[playbooks-folder]: ./../playbooks
[alien-folder]: ./../alien
[alien-commands]: ./../dotfiles/common/scripts/alien.sh

[ansible-website]: https://www.ansible.com
[dotfiles-website]: http://dotfiles.github.io
[dotfiles-website2]: https://wiki.nikitavoloboev.xyz/unix/dotfiles
[docopt-website]: http://docopt.org
[dotbot-website]: https://github.com/anishathalye/dotbot

[fzf]: https://github.com/junegunn/fzf

[dotly]: https://github.com/CodelyTV/dotly

[stable-checks-badge]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-checks.yml/badge.svg
[stable-checks-workflow]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-checks.yml

[stable-build-badge]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-build.yml/badge.svg
[stable-build-workflow]: https://github.com/hpedrorodrigues/sphynx/actions/workflows/stable-build.yml

[homebrew]: https://brew.sh
[linuxbrew]: https://docs.brew.sh/Homebrew-on-Linux
