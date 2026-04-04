mod doom 'DoomFrequency/doom.just'
mod relayer 'relayer/relayer.just'

default:
  just --list --list-submodules

umbrella := "DoomFrequency/vendor/umbrella"

submodule-init:
  git submodule add git@github.com:PZ-Umbrella/Umbrella.git {{umbrella}} || true
  git -C {{umbrella}} fetch --tags
  git -C {{umbrella}} checkout 42.16.0

submodule-remove:
  git rm -f {{umbrella}} || true
  rm -rf .git/modules/{{umbrella}}
  git config --remove-section submodule.{{umbrella}} || true
  git config -f .gitmodules --remove-section submodule.{{umbrella}} || true
  rm -rf {{umbrella}}

submodule-sync:
  git submodule update --init --recursive

submodule-upgrade:
  git submodule update --init --recursive --remote
