#!/usr/bin/env python

"""Lint the "##?" help templates of Sphynx commands.

Conventions enforced (see also `sx <namespace> <command> --help`):
- the first help line is a meaningful title
- a "Usage:" section where every pattern is a single 4-space-indented line
  starting with the command name (no wrapped/continuation lines)
- an "Options:" section whenever usage references options, documenting every
  long option used in usage and containing no entry that usage never uses
- an "Examples:" section where every plain invocation parses against the
  template
- no reserved global flag (--help/--raw/--github) redefined by the template
- every option/argument variable exported by the template is referenced in
  the script (no dead flags, no renames that silently break a branch)

Usage: docopt_lint.py <command-file>...
"""

from __future__ import print_function

import os
import re
import shlex
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from docopt import (
    Argument,
    DocoptLanguageError,
    Option,
    docopt,
    formal_usage,
    parse_defaults,
    parse_pattern,
    parse_section,
)

HELP_PREFIX = "##?"
SECTION_PATTERN = re.compile(r"^(\w[\w ]*):\s*$")
LONG_OPTION_PATTERN = re.compile(r"--[a-z][a-z-]*")
SHORT_OPTION_PATTERN = re.compile(r"(?<![-\w])-[a-zA-Z](?![\w-])")
RESERVED_FLAGS = frozenset(("--help", "--raw", "--github"))


def parse_sections(lines):
    sections = {}
    section = None
    for line in lines:
        match = SECTION_PATTERN.match(line)
        if match:
            section = match.group(1).lower()
            sections.setdefault(section, [])
        elif section is not None and line.strip():
            sections[section].append(line)
    return sections


def option_tokens(text):
    tokens = set(LONG_OPTION_PATTERN.findall(text))
    tokens.update(SHORT_OPTION_PATTERN.findall(text))
    return tokens


def lint_usage(problems, usage, program):
    usage_options = set()

    if not usage:
        problems.append('the "Usage:" section must have at least one pattern')

    for line in usage:
        if not re.match(r"^    \S", line):
            problems.append(
                "usage pattern must be a single line indented with 4 spaces: %r"
                % line.strip()
            )
            continue
        if line.split()[0] != program:
            problems.append(
                "usage pattern must start with the command name %r: %r"
                % (program, line.strip())
            )
        usage_options.update(option_tokens(line))

    return usage_options


def lint_options(problems, options, usage_options):
    declared = set()
    if options is None:
        if usage_options:
            problems.append(
                'usage references options but there is no "Options:" section'
            )
        return declared

    entries = []
    for line in options:
        if re.match(r"^    -", line):
            head = re.split(r"\s{2,}", line.strip())[0]
            aliases = option_tokens(head)
            declared.update(aliases)
            entries.append((head, aliases))
        elif not re.match(r"^     ", line):
            problems.append(
                "options entry must be indented with 4 spaces"
                " (continuation lines with 5+): %r" % line.strip()
            )

    declared_longs = set(alias for alias in declared if alias.startswith("--"))
    long_usage_options = set(
        option for option in usage_options if option.startswith("--")
    )
    for option in sorted(long_usage_options - declared_longs):
        problems.append(
            'usage option %r is not documented in the "Options:" section' % option
        )

    for head, aliases in entries:
        if not aliases & usage_options:
            problems.append("options entry %r is never referenced in usage" % head)

    return declared


def lint_reserved_flags(problems, flags):
    for flag in sorted(flags & RESERVED_FLAGS):
        problems.append(
            '%r is a reserved global flag handled by "sx::parse_arguments"' % flag
        )


def variable_name(element):
    name = element.name
    if name in ("-", "--"):
        return None
    if name.startswith("<"):
        name = name[1:-1]
    else:
        name = name.lstrip("-")
    return name.replace("-", "_")


def lint_variables(problems, document, body):
    options = parse_defaults(document)
    usage = parse_section("usage:", document)[0]
    pattern = parse_pattern(formal_usage(usage), options)

    names = set()
    for element in pattern.flat(Option, Argument):
        name = variable_name(element)
        if name:
            names.add(name)

    for name in sorted(names):
        if not re.search(r"\$\{%s[}:\[]" % re.escape(name), body):
            problems.append(
                "template variable %r is never referenced in the script" % name
            )


def lint_examples(problems, examples, document, program):
    if examples is None:
        problems.append('missing "Examples:" section')
        return

    plain_invocations = 0
    for line in examples:
        try:
            tokens = shlex.split(line.strip())
        except ValueError:
            continue
        if not tokens or tokens[0] != program:
            continue
        plain_invocations += 1
        try:
            docopt(document, argv=tokens[1:], help=False)
        except SystemExit:
            problems.append(
                "example does not match any usage pattern: %r" % line.strip()
            )

    if not plain_invocations:
        problems.append(
            'the "Examples:" section must have at least one plain %r invocation'
            % program
        )


def lint(path):
    with open(path) as stream:
        source = stream.read()

    lines = [line[4:] for line in source.splitlines() if line.startswith(HELP_PREFIX)]
    if not lines:
        return ['no "##?" help template found']

    problems = []
    if not lines[0].strip() or lines[0].rstrip().endswith(":"):
        problems.append("the first help line must be a meaningful title")

    document = "\n".join(lines)
    body = "\n".join(
        line for line in source.splitlines() if not line.startswith(HELP_PREFIX)
    )
    program = os.path.basename(path)
    sections = parse_sections(lines)

    if "usage" not in sections:
        problems.append('missing "Usage:" section')
        return problems

    usage_options = lint_usage(problems, sections["usage"], program)
    declared_options = lint_options(problems, sections.get("options"), usage_options)
    lint_reserved_flags(problems, usage_options | declared_options)

    try:
        docopt(document, argv=["--sphynx-lint-probe"], help=False)
    except DocoptLanguageError as error:
        problems.append("invalid docopt template: %s" % error)
        return problems
    except SystemExit:
        pass

    lint_variables(problems, document, body)
    lint_examples(problems, sections.get("examples"), document, program)

    return problems


def main(paths):
    exit_code = 0
    for path in paths:
        for problem in lint(path):
            exit_code = 1
            print("%s: %s" % (path, problem), file=sys.stderr)
    return exit_code


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: docopt_lint.py <command-file>...", file=sys.stderr)
        sys.exit(2)
    sys.exit(main(sys.argv[1:]))
