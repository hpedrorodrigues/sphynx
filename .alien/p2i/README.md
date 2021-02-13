# p2i

The idea behind this script is to provide an easy way to convert web pages (or part of them) into images.

```
Options:
      --help      Show help                                            [boolean]
      --version   Show version number                                  [boolean]
  -u, --url       The URL to take the screenshot             [string] [required]
  -f, --filename  The file path to save the image to                    [string]
  -s, --selector  A query selector to be used to screenshot an element  [string]
  -w, --width     The screenshot resolution width                       [number]
  -h, --height    The screenshot resolution height                      [number]
```

## Dependencies

- https://github.com/puppeteer/puppeteer
- https://github.com/yargs/yargs

## References

- https://docs.docker.com/engine/security/seccomp
- https://github.com/jessfraz/dotfiles/blob/master/etc/docker/seccomp/chrome.json
