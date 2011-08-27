" rhubarb.vim - fugitive.vim extension for GitHub
" Maintainer:   Tim Pope <http://tpo.pe/>

if exists("g:loaded_rhubarb") || v:version < 700 || &cp
  finish
endif
let g:loaded_rhubarb = 1

" Utility {{{1

function! s:throw(string) abort
  let v:errmsg = 'rhubarb: '.a:string
  throw v:errmsg
endfunction

function! s:repo_name()
  if !exists('b:github_repo')
    let repo = fugitive#buffer().repo()
    let url = repo.config('remote.origin.url')
    if url !~# 'github\.com[:/][^/]*/[^/]*\.git'
      call s:throw('origin is not a GitHub repository: '.url)
    endif
    let b:github_repo = matchstr(url,'github\.com[:/]\zs[^/]*/[^/]*\ze\.git')
  endif
  return b:github_repo
endfunction

" }}}1
" HTTP {{{1

function! s:credentials()
  if !exists('g:github_user')
    let g:github_user = $GITHUB_USER
    if g:github_user ==# ''
      let g:github_user = system('git config --get github.user')[0:-2]
    endif
    if g:github_user ==# ''
      let g:github_user = $LOGNAME
    endif
  endif
  if !exists('g:github_token')
    let g:github_token = $GITHUB_TOKEN
    if g:github_token ==# ''
      let g:github_token = system('git config --get github.token')[0:-2]
    endif
  endif
  return g:github_user.'/token:'.g:github_token
endfunction

function! rhubarb#json_parse(string)
  let [null, false, true] = ['', 0, 1]
  let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
  if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
    try
      return eval(substitute(a:string,"[\r\n]"," ",'g'))
    catch
    endtry
  endif
  call s:throw("invalid JSON: ".stripped)
endfunction

function! rhubarb#get(path)
  if !executable('curl')
    call s:throw('cURL is required')
  endif
  let url = a:path =~# '://' ? a:path : 'https://github.com/api/v2/json'.a:path
  let url = substitute(url,'%s','\=s:repo_name()','')
  let output = system('curl -s -L -H "Accept: application/json" -H "Content-Type: application/json" -u "'.s:credentials().'" '.url)
  return rhubarb#json_parse(output)
endfunction

" }}}1
" Issues {{{1

function! rhubarb#issues(...)
  return rhubarb#get('/issues/list/%s/'.(a:0 ? a:1 : 'open'))['issues']
endfunction

function! rhubarb#omnifunc(findstart,base)
  if a:findstart
    let existing = matchstr(getline('.')[0:col('.')-1],'#\d*$')
    return col('.')-1-strlen(existing)
  endif
  try
    return map(reverse(rhubarb#issues()),'{"word": "#".v:val.number, "menu": v:val.title, "info": substitute(v:val.body,"\\r","","g")}')
  catch /^\%(fugitive\|rhubarb\):/
    return v:errmsg
  endtry
endfunction

augroup rhubarb
  autocmd!
  autocmd User Fugitive
        \ if fugitive#buffer().path() =~# '^\.git.COMMIT_EDITMSG$' &&
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

" }}}1

" vim:set sw=2 sts=2:
