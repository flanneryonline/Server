#!/usr/bin/env sh

curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
ln -s server/dotfiles/dot.vim ../.vim
ln -s server/dotfiles/dot.vimrc ../.vimrc
ln -s server/dotfiles/dot.zshrc ../.zshrc
ln -s server/dotfiles/dot.tmux.conf ../.tmux.conf
