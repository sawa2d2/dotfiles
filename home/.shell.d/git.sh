ghome() {
  GIT_PROJECT_ROOT=$(git rev-parse --show-toplevel)
  cd $GIT_PROJECT_ROOT
}

# Delete local branches squash-merged on origin after a successful fetch or pull.
# gprune refetches with --prune because a plain fetch keeps deleted remote refs.
git() {
  command git "$@" || return
  case ${1:-} in
    fetch|pull) command gprune --quiet || true ;;
  esac
}
