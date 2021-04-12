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

function! s:Config() abort
  if exists('*FugitiveFind')
    let dir = FugitiveFind('.git/config')[0:-8]
    return filereadable(dir . '/config') ? readfile(dir . '/config') : []
  else
    return []
  endif
endfunction

augroup rhubarb
  autocmd!
  autocmd User Fugitive
        \ if expand('%:p') =~# '\.git[\/].*MSG$' &&
        \   exists('+omnifunc') &&
        \   &omnifunc =~# '^\%(syntaxcomplete#Complete\)\=$' &&
        \   !empty(filter(s:Config(),
        \     '!empty(rhubarb#HomepageForUrl(matchstr(v:val, ''^\s*url\s*=\s*"\=\zs\S*'')))')) |
        \   setlocal omnifunc=rhubarb#Complete |
        \ endif
  autocmd BufEnter *
        \ if expand('%') ==# '' && &previewwindow && pumvisible() && getbufvar('#', '&omnifunc') ==# 'rhubarb#omnifunc' |
        \    setlocal nolist linebreak filetype=markdown |
        \ endif
  autocmd BufNewFile,BufRead *.git/{PULLREQ_EDIT,ISSUE_EDIT,RELEASE_EDIT}MSG
        \ if &ft ==# '' || &ft ==# 'conf' |
        \   set ft=gitcommit |
        \ endif
augroup END

if !exists('g:fugitive_browse_handlers')
  let g:fugitive_browse_handlers = []
endif

if index(g:fugitive_browse_handlers, function('rhubarb#FugitiveUrl')) < 0
  call insert(g:fugitive_browse_handlers, function('rhubarb#FugitiveUrl'))
endif
