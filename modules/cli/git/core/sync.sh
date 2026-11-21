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

    sx::git::sync::repository "${reset_requested}" "$(git rev-parse --show-toplevel)"
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
  local -a update_arguments

  if ${reset_requested}; then
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
  local branch_name branch_commit
  while read -r branch_name branch_commit; do
    if [ "${branch_name}" = "${default_branch}" ]; then
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
      --format='%(refname:lstrip=2) %(objectname:short)' 'refs/heads'
  )

  if ${delete_failed}; then
    return 1
  fi
}
