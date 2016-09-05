#!/usr/bin/env bash

set -o errexit
set -o nounset

ln -s server/dotfiles/dot.vim ../.vim
ln -s server/dotfiles/dot.vimrc ../.vimrc
ln -s server/dotfiles/dot.zshrc ../.zshrc
ln -s server/dotfiles/dot.tmux.conf ../.tmux.conf
