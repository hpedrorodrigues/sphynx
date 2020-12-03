<p align="center">
  <img src="./.github/assets/sphynx-landscape.png" align="center" height="50%" width="50%"/>
</p>

[![][github-action-badge]][github-action-sphynx]
[![][written-in-badge]][shell-code-sphynx]

Sphynx is a personal project including CLI, dotfiles, workspace setup scripts
among other things.

<img align="right" src="./.github/assets/sphynx-demo.gif" width="60%" />

# Summary

- [About](#about)
  - [CLI](#cli)
  - [Dotfiles](#dotfiles)
  - [Alien scripts](#alien-scripts)
  - [Workspace configuration](#workspace-configuration)
- [Installation](#installation)

## About

This project has 4 main components that will be described below.

### CLI

Sphynx provides a command-line interface to handle all stuff related with
this project using [docopt][docopt-website].

The commands are configured using environment variables, and each command can
have its own settings. For instance, `sx kubernetes ls` uses the env var
`SX_KUBERNETES_RESOURCES` to know what resources to list.

Most commands use the [fuzzy finder][fzf] to provide a better experience with an
interactive menu + fuzzy searching, and even though it's not a mandatory
dependency it could be good installing it.

### Dotfiles

All dotfiles are inside [.file][dotfiles-folder] directory. It has common
aliases, functions, and configuration files that you may use day to day.

The command-line provides a command (`sx dotfiles configure`) to bootstrap
dotfiles using [dotbot][dotbot-website], but remember it will overwrite your
files! Beware!

**How about shell startup performance?**

**zsh**
```bash
♪ repeat 5 { /usr/bin/time zsh -i -c exit }
        0.10 real         0.05 user         0.04 sys
        0.11 real         0.06 user         0.04 sys
        0.11 real         0.06 user         0.04 sys
        0.11 real         0.06 user         0.04 sys
        0.12 real         0.06 user         0.05 sys
```

**bash**
```bash
♪ repeat 5 { /usr/bin/time bash -i -c exit }
        0.10 real         0.06 user         0.06 sys
        0.10 real         0.06 user         0.05 sys
        0.09 real         0.06 user         0.05 sys
        0.09 real         0.06 user         0.05 sys
        0.10 real         0.06 user         0.05 sys
```

**Inspiration**:

- [denisidoro/dotfiles](https://github.com/denisidoro/dotfiles)
- [mathiasbynens/dotfiles](https://github.com/mathiasbynens/dotfiles)
- [jessfraz/dotfiles](https://github.com/jessfraz/dotfiles)

Also, [Github ❤ ~/][dotfiles-website] and
[Everything I know - Dotfiles][dotfiles-website2] are your friends.

### Alien scripts

Alien commands are tools that you don't want to install on your machine and
still use it. For instance, you want to use [p2i][p2i] but you don't want to
configure a nodejs environment.

> Sphynx is using Docker to accomplish this goal.

All alien commands are exposed as functions [here][alien-functions] but note
that not all functions use the dockerfiles available in this project
(e.g. Kafka and Zookeeper).

### Workspace configuration

[Ansible][ansible-website] playbooks are recipes that install tools on your
machine.

It automates tedious tasks installing packages and applications that you use
(maybe) almost daily.

If you want to run the playbooks, type `sx playbook run` in your terminal.

> Before running this command, take a look at the source code and adjust it to
> your needs!

## Installation

If you want to give the CLI a try, you can use [Homebrew][homebrew] or
[Linuxbrew][linuxbrew] to install it.

```bash
brew install hpedrorodrigues/tools/sphynx
```

But if you want to give this whole project a try, it's recommended you fork
this repository and adjust it to your needs! Be careful!



[dotfiles-folder]: ./.file
[playbooks-folder]: ./.playbook
[alien-folder]: ./.alien
[alien-functions]: ./.file/common/alien
[p2i]: ./.alien/p2i

[ansible-website]: https://www.ansible.com
[dotfiles-website]: http://dotfiles.github.io
[dotfiles-website2]: https://wiki.nikitavoloboev.xyz/unix/dotfiles
[docopt-website]: http://docopt.org
[dotbot-website]: https://github.com/anishathalye/dotbot

[fzf]: https://github.com/junegunn/fzf

[github-action-badge]: https://github.com/hpedrorodrigues/sphynx/workflows/Checks/badge.svg
[github-action-sphynx]: https://github.com/hpedrorodrigues/sphynx/actions

[written-in-badge]: https://img.shields.io/badge/Written%20in-bash-ff69b4.svg
[shell-code-sphynx]: https://github.com/hpedrorodrigues/sphynx/search?l=shell

[homebrew]: https://brew.sh
[linuxbrew]: https://linuxbrew.sh
