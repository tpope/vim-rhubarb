# rhubarb.vim

If [fugitive.vim][] is the Git, rhubarb.vim is the Hub.  Here's the full list
of features:

* Enables `:Gbrowse` from fugitive.vim to open GitHub URLs.  (`:Gbrowse`
  currently has native support for this, but it is slated to be removed.)

* In commit messages, GitHub issues, issue URLs, and collaborators can be
  omni-completed (`<C-X><C-O>`, see `:help compl-omni`).  This makes inserting
  those `Closes #123` remarks slightly easier than copying and pasting from
  the browser.

[fugitive.vim]: https://github.com/tpope/vim-fugitive

## Installation

If you don't have a preferred installation method, I recommend
installing [pathogen.vim](https://github.com/tpope/vim-pathogen), and
then simply copy and paste:

    cd ~/.vim/bundle
    git clone https://github.com/tpope/vim-rhubarb.git
    vim -u NONE -c "helptags vim-rhubarb/doc" -c q

In addition to [fugitive.vim][], [Curl](http://curl.haxx.se/) is
required (included with macOS).

Provide your GitHub credentials by adding them to your netrc:

    echo 'machine api.github.com login <user> password <password>' >> ~/.netrc

If you'd rather not store your password in plain text, you can
[generate a personal access token](https://github.com/settings/tokens/new)
and use that instead:

    echo 'machine api.github.com login <token> password x-oauth-basic' \
      >> ~/.netrc

If you are using GitHub Enterprise, repeat those steps for each domain (omit
the `api.` portion). You'll also need to tell Rhubarb the root URLs:

    let g:github_enterprise_urls = ['https://example.com']

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
