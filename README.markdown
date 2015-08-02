# rhubarb.vim

If [fugitive.vim][] is the Git, rhubarb.vim is the Hub.  Or at least it
could be.  One day.  Right now it's pretty stupid.  I almost named it
chubby.vim, but it just didn't feel right.

So far there's only one feature:  In Git commit messages, GitHub issues
and collaborators can be omni-completed (`<C-X><C-O>`, see `:help
compl-omni`).  This makes inserting those `Closes #123` remarks slightly
easier than copying and pasting from the browser.

Maybe I'll extract `:Gbrowse` out of fugitive.vim and put it here
instead.  Or maybe I'll add some cool Gist stuff.  You never know with
rhubarb.vim.

[fugitive.vim]: https://github.com/tpope/vim-fugitive

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone git://github.com/tpope/vim-rhubarb.git
    vim -u NONE -c "helptags vim-rhubarb/doc" -c q

In addition to [fugitive.vim][], [Curl](http://curl.haxx.se/) is
required (included with OS X).

Provide your GitHub credentials by adding them to your netrc:

    echo 'machine api.github.com login <user> password <password>' >> ~/.netrc

There is not currently built-in support for OAuth, but you can add a token to
your netrc if you fetch it by hand:

    echo 'machine api.github.com login <token> password x-oauth-basic' \
      >> ~/.netrc

## FAQ

> How do I turn off that preview window that shows the issue body?

    set completeopt-=preview

## Self-Promotion

Like rhubarb.vim? Follow the repository on
[GitHub](https://github.com/tpope/vim-rhubarb).  And if
you're feeling especially charitable, follow [tpope](http://tpo.pe/) on
[Twitter](http://twitter.com/tpope) and
[GitHub](https://github.com/tpope).

## License

Copyright (c) Tim Pope.  Distributed under the same terms as Vim itself.
See `:help license`.
