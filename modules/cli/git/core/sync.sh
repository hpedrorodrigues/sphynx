#!/usr/bin/env bash

function sx::git::sync() {
  local -r reset_requested="${1:-false}"
  local -r folder="${2:-}"

  if [ -n "${folder}" ]; then
    sx::require 'git'

    if [ ! -d "${folder}" ]; then
      sx::log::fatal "No such folder \"${folder}\""
    fi

    sx::git::sync::folder "${reset_requested}" "${folder}"
  else
    sx::git::check_requirements

    local -r repository_path="$(git rev-parse --show-toplevel)"

    if ${reset_requested} && sx::git::sync::is_linked_worktree "${repository_path}"; then
      local -r main_worktree="$(sx::git::sync::main_worktree "${repository_path}")"

      sx::log::fatal "The --reset option removes linked worktrees. Run it from the main checkout \"${main_worktree}\""
    fi

    sx::git::sync::repository "${reset_requested}" "${repository_path}"
  fi
}

function sx::git::sync::folder() {
  local -r reset_requested="${1:-false}"
  local -r folder="${2:-}"
  local -r max_parallel_jobs='8'

  local running_jobs='0'
  local failed_jobs='0'
  local repository_count='0'
  local git_directory

  for git_directory in "${folder}"/*/.git; do
    if [ ! -e "${git_directory}" ]; then
      continue
    fi

    if [ -f "${git_directory}" ] && sx::git::sync::is_linked_worktree "${git_directory%/.git}"; then
      continue
    fi

    if [ "${running_jobs}" -ge "${max_parallel_jobs}" ]; then
      wait -n || failed_jobs="$((failed_jobs + 1))"
      running_jobs="$((running_jobs - 1))"
    fi

    sx::git::sync::repository "${reset_requested}" "${git_directory%/.git}" &

    running_jobs="$((running_jobs + 1))"
    repository_count="$((repository_count + 1))"
  done

  while [ "${running_jobs}" -gt 0 ]; do
    wait -n || failed_jobs="$((failed_jobs + 1))"
    running_jobs="$((running_jobs - 1))"
  done

  if [ "${repository_count}" -eq 0 ]; then
    sx::log::fatal "No git repositories found in \"${folder}\""
  fi

  if [ "${failed_jobs}" -gt 0 ]; then
    return 1
  fi
}

function sx::git::sync::repository() {
  local -r reset_requested="${1:-false}"
  local -r repository_path="${2:-}"

  if [ -z "${repository_path}" ]; then
    sx::log::fatal 'This function needs a repository path as second argument'
  fi

  local -r repository_name="$(basename "${repository_path}")"
  local command_output

  if ! command_output="$(
    git -C "${repository_path}" -c 'remote.origin.followRemoteHEAD=always' \
      fetch --prune --quiet origin 2>&1
  )"; then
    sx::log::errn "failed    ${repository_name}: ${command_output%%$'\n'*}"
    return 1
  fi

  local remote_reference
  if ! remote_reference="$(
    git -C "${repository_path}" symbolic-ref --quiet 'refs/remotes/origin/HEAD'
  )"; then
    sx::log::errn "failed    ${repository_name}: origin has no default branch"
    return 1
  fi

  local -r default_branch="${remote_reference#refs/remotes/origin/}"
  local -r local_reference="refs/heads/${default_branch}"
  local -r commit_before="$(
    git -C "${repository_path}" rev-parse --quiet --verify --short "${local_reference}"
  )"

  local changed_files='0'
  local worktrees_kept='false'
  local -a update_arguments

  if ${reset_requested}; then
    if [ "$(git -C "${repository_path}" rev-parse --is-bare-repository)" = 'true' ]; then
      sx::log::errn "failed    ${repository_name}: --reset needs a main checkout"
      return 1
    fi

    sx::git::sync::remove_worktrees "${repository_path}" "${repository_name}" \
      || worktrees_kept='true'

    changed_files="$(
      git -C "${repository_path}" status --porcelain --untracked-files=no \
        | grep --count '' || true
    )"
    update_arguments=(
      switch --quiet --discard-changes
      --force-create "${default_branch}" "${remote_reference}"
    )
  elif git -C "${repository_path}" merge-base --is-ancestor \
    "${remote_reference}" "${local_reference}" 2>/dev/null; then
    return 0
  elif [ -n "${commit_before}" ] && ! git -C "${repository_path}" merge-base --is-ancestor \
    "${local_reference}" "${remote_reference}"; then
    sx::log::errn "skipped   ${repository_name}: ${default_branch} has diverged from origin"
    return 1
  elif [ "$(git -C "${repository_path}" symbolic-ref --quiet --short HEAD)" = "${default_branch}" ]; then
    update_arguments=(merge --ff-only --quiet "${remote_reference}")
  else
    update_arguments=(fetch --quiet . "${remote_reference}:${local_reference}")
  fi

  if ! command_output="$(
    git -C "${repository_path}" "${update_arguments[@]}" 2>&1
  )"; then
    sx::log::errn "failed    ${repository_name}: ${command_output%%$'\n'*}"
    return 1
  fi

  local -r commit_after="$(
    git -C "${repository_path}" rev-parse --short "${local_reference}"
  )"

  if [ "${commit_before}" != "${commit_after}" ]; then
    sx::log::info "updated   ${repository_name}: ${default_branch} ${commit_before:-none}..${commit_after}"
  fi

  if ! ${reset_requested}; then
    return 0
  fi

  if [ "${changed_files}" -gt 0 ]; then
    sx::log::info "discarded ${repository_name}: ${changed_files} changed files"
  fi

  local delete_failed='false'
  local branch_name branch_commit branch_worktree
  while read -r branch_name branch_commit branch_worktree; do
    if [ "${branch_name}" = "${default_branch}" ] || [ -n "${branch_worktree}" ]; then
      continue
    fi

    if command_output="$(
      git -C "${repository_path}" branch --delete --force --quiet "${branch_name}" 2>&1
    )"; then
      sx::log::info "deleted   ${repository_name}: ${branch_name} (was ${branch_commit})"
    else
      sx::log::errn "failed    ${repository_name}: ${command_output%%$'\n'*}"
      delete_failed='true'
    fi
  done < <(
    git -C "${repository_path}" for-each-ref \
      --format='%(refname:lstrip=2) %(objectname:short) %(worktreepath)' 'refs/heads'
  )

  if ${delete_failed} || ${worktrees_kept}; then
    return 1
  fi
}

function sx::git::sync::remove_worktrees() {
  local -r repository_path="${1:-}"
  local -r repository_name="${2:-}"

  local main_worktree=''
  local worktree_kept='false'
  local worktree_state worktree_commit worktree_path worktree_name
  local changed_files command_output

  while IFS=$'\t' read -r worktree_state worktree_commit worktree_path; do
    if [ -z "${main_worktree}" ]; then
      main_worktree="${worktree_path}"
      continue
    fi

    worktree_name="${worktree_path#"${main_worktree}/"}"

    if [ "${worktree_state}" = 'locked' ]; then
      sx::log::errn "skipped   ${repository_name}: worktree ${worktree_name} is locked"
      worktree_kept='true'
      continue
    fi

    changed_files="$(
      git -C "${worktree_path}" status --porcelain --untracked-files=all 2>/dev/null \
        | grep --count '' || true
    )"
    worktree_commit="$(
      git -C "${repository_path}" rev-parse --short "${worktree_commit}"
    )"

    if ! command_output="$(
      git -C "${repository_path}" worktree remove --force "${worktree_path}" 2>&1
    )"; then
      sx::log::errn "failed    ${repository_name}: ${command_output%%$'\n'*}"
      worktree_kept='true'
      continue
    fi

    sx::log::info "removed   ${repository_name}: worktree ${worktree_name} (was ${worktree_commit})"

    if [ "${changed_files}" -gt 0 ]; then
      sx::log::info "discarded ${repository_name}: ${changed_files} changed files in worktree ${worktree_name}"
    fi
  done < <(sx::git::sync::worktrees "${repository_path}")

  if ${worktree_kept}; then
    return 1
  fi
}

function sx::git::sync::worktrees() {
  local -r repository_path="${1:-}"

  local worktree_path=''
  local worktree_commit='-'
  local worktree_state='unlocked'
  local line

  while IFS= read -r line; do
    case "${line}" in
      'worktree '*) worktree_path="${line#worktree }" ;;
      'HEAD '*) worktree_commit="${line#HEAD }" ;;
      'locked' | 'locked '*) worktree_state='locked' ;;
      '')
        printf '%s\t%s\t%s\n' "${worktree_state}" "${worktree_commit}" "${worktree_path}"
        worktree_commit='-'
        worktree_state='unlocked'
        ;;
    esac
  done < <(git -C "${repository_path}" worktree list --porcelain)
}

function sx::git::sync::main_worktree() {
  local -r repository_path="${1:-}"

  local worktree_path
  IFS=$'\t' read -r _ _ worktree_path < <(sx::git::sync::worktrees "${repository_path}")

  echo "${worktree_path}"
}

function sx::git::sync::is_linked_worktree() {
  local -r repository_path="${1:-}"

  local -r git_directory="$(
    git -C "${repository_path}" rev-parse --path-format=absolute --git-dir 2>/dev/null
  )"
  local -r common_directory="$(
    git -C "${repository_path}" rev-parse --path-format=absolute --git-common-dir 2>/dev/null
  )"

  [ "${git_directory}" != "${common_directory}" ]
}
