#!/usr/bin/env sh

#vim
curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
ln -s ~/server/dotfiles/dot.vimrc ~/.vimrc

#zsh
ln -s ~/server/dotfiles/dot.zshrc ~/.zshrc

#tmux
ln -s ~/server/dotfiles/dot.tmux.conf ~/.tmux.conf

#freebsd base stuff
ln -s ~/server/dotfiles/dot.shrc ~/.shrc
ln -s ~/server/dotfiles/dot.login.conf ~/.login.conf
ln -s ~/server/dotfiles/dot.login.conf.db ~/.login.conf.db
ln -s ~/server/dotfiles/dot.profile ~/.profile

