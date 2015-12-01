" rhubarb.vim - fugitive.vim extension for GitHub
" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:loaded_rhubarb") || v:version < 700 || &cp
  finish
endif
let g:loaded_rhubarb = 1

if get(g:, 'fugitive_git_executable', 'git') ==# 'git' && executable('hub')
  let g:fugitive_git_executable = 'hub'
endif

if !exists('g:dispatch_compilers')
  let g:dispatch_compilers = {}
endif
let g:dispatch_compilers['hub'] = 'git'

augroup rhubarb
  autocmd!
  autocmd User Fugitive
        \ if expand('%:p') =~# '\.git[\/].*MSG$' &&
        \   exists('+omnifunc') &&
        \   &omnifunc =~# '^\%(syntaxcomplete#Complete\)\=$' &&
        \   join(readfile(fugitive#buffer().repo().dir('config')),"\n")
        \     =~# '\n[^;]*github\.com' |
        \   setlocal omnifunc=rhubarb#omnifunc |
        \ endif
  autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'rhubarb#omnifunc' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
augroup END
