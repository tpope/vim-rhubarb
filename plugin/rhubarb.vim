" rhubarb.vim - fugitive.vim extension for GitHub
" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:loaded_rhubarb") || v:version < 700 || &cp
  finish
endif
let g:loaded_rhubarb = 1

if !exists('g:dispatch_compilers')
  let g:dispatch_compilers = {}
endif
let g:dispatch_compilers['hub'] = 'git'

if get(g:, 'fugitive_git_command', 'git') ==# 'git' && executable('hub')
  let g:fugitive_git_command = 'hub'
endif

function! s:config() abort
  let common_dir = fugitive#buffer().repo().dir('commondir')
  if filereadable(common_dir)
    return fugitive#buffer().repo().dir(readfile(common_dir)[0] . '/config')
  endif
  return fugitive#buffer().repo().dir('config')
endfunction

augroup rhubarb
  autocmd!
  autocmd User Fugitive
        \ if expand('%:p') =~# '\.git[\/].*MSG$' &&
        \   exists('+omnifunc') &&
        \   &omnifunc =~# '^\%(syntaxcomplete#Complete\)\=$' &&
        \   !empty(filter(readfile(s:config()),
        \     '!empty(rhubarb#homepage_for_url(matchstr(v:val, ''^\s*url\s*=\s*"\=\zs\S*'')))')) |
        \   setlocal omnifunc=rhubarb#omnifunc |
        \ endif
  autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'rhubarb#omnifunc' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
augroup END

if !exists('g:fugitive_browse_handlers')
  let g:fugitive_browse_handlers = []
endif

if index(g:fugitive_browse_handlers, function('rhubarb#fugitive_url')) < 0
  call insert(g:fugitive_browse_handlers, function('rhubarb#fugitive_url'))
endif
