function ghome() {
  GIT_PROJECT_ROOT=$(git rev-parse --show-toplevel)
  cd $GIT_PROJECT_ROOT
}
