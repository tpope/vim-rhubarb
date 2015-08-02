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

" Utility {{{1

function! s:throw(string) abort
  let v:errmsg = 'rhubarb: '.a:string
  throw v:errmsg
endfunction

function! s:shellesc(arg) abort
  if a:arg =~ '^[A-Za-z0-9_/.-]\+$'
    return a:arg
  elseif &shell =~# 'cmd' && a:arg !~# '"'
    return '"'.a:arg.'"'
  else
    return shellescape(a:arg)
  endif
endfunction

function! s:homepage_for_url(url) abort
  let domain_pattern = 'github\.com'
  let domains = get(g:, 'github_enterprise_urls', get(g:, 'fugitive_github_domains', []))
  call map(copy(domains), 'substitute(v:val, "/$", "", "")')
  for domain in domains
    let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
  endfor
  let repo = fugitive#buffer().repo()
  let base = matchstr(a:url, '^\%(https\=://\|git://\|git@\)\=\zs\('.domain_pattern.'\)[/:].\{-\}\ze\%(\.git\)\=$')
  if index(domains, 'http://' . matchstr(base, '^[^:/]*')) >= 0
    return 'http://' . tr(base, ':', '/')
  elseif !empty(base)
    return 'https://' . tr(base, ':', '/')
  endif
  call s:throw('not a GitHub repository: '.a:url)
endfunction

function! s:repo_homepage() abort
  if !exists('b:rhubarb_homepage')
    let repo = fugitive#buffer().repo()
    let url = repo.config('remote.origin.url')
    let b:rhubarb_homepage = s:homepage_for_url(url)
  endif
  return b:rhubarb_homepage
endfunction

" }}}1
" HTTP {{{1

function! s:credentials() abort
  if !exists('g:github_user')
    let g:github_user = $GITHUB_USER
    if g:github_user ==# ''
      let g:github_user = system('git config --get github.user')[0:-2]
    endif
    if g:github_user ==# ''
      let g:github_user = $LOGNAME
    endif
  endif
  if !exists('g:github_password')
    let g:github_password = $GITHUB_PASSWORD
    if g:github_password ==# ''
      let g:github_password = system('git config --get github.password')[0:-2]
    endif
  endif
  return g:github_user.':'.g:github_password
endfunction

function! rhubarb#json_parse(string) abort
  let [null, false, true] = ['', 0, 1]
  let stripped = substitute(a:string,'\C"\(\\.\|[^"\\]\)*"','','g')
  if stripped !~# "[^,:{}\\[\\]0-9.\\-+Eaeflnr-u \n\r\t]"
    try
      return eval(substitute(a:string,"[\r\n]"," ",'g'))
    catch
    endtry
  endif
  call s:throw("invalid JSON: ".a:string)
endfunction

function! rhubarb#json_generate(object) abort
  if type(a:object) == type('')
    return '"' . substitute(a:object, "[\001-\031\"\\\\]", '\=printf("\\u%04x", char2nr(submatch(0)))', 'g') . '"'
  elseif type(a:object) == type([])
    return '['.join(map(copy(a:object), 'rhubarb#json_generate(v:val)'),', ').']'
  elseif type(a:object) == type({})
    let pairs = []
    for key in keys(a:object)
      call add(pairs, rhubarb#json_generate(key) . ': ' . rhubarb#json_generate(a:object[key]))
    endfor
    return '{' . join(pairs, ', ') . '}'
  else
    return string(a:object)
  endif
endfunction

function! s:curl_arguments(path, ...) abort
  let options = a:0 ? a:1 : {}
  let args = ['-q', '--silent']
  call extend(args, ['-H', 'Accept: application/json'])
  call extend(args, ['-H', 'Content-Type: application/json'])
  call extend(args, ['-A', 'rhubarb.vim'])
  if get(options, 'auth', '') =~# ':'
    call extend(args, ['-u', options.auth])
  elseif has_key(options, 'auth')
    call extend(args, ['-H', 'Authorization: bearer ' . options.auth])
  elseif exists('g:RHUBARB_TOKEN')
    call extend(args, ['-H', 'Authorization: bearer ' . g:RHUBARB_TOKEN])
  elseif s:credentials() !~# '^[^:]*:$'
    call extend(args, ['-u', s:credentials()])
  else
    call extend(args, ['--netrc'])
  endif
  if has_key(options, 'method')
    call extend(args, ['-X', toupper(options.method)])
  endif
  if type(get(options, 'data', '')) != type('')
    call extend(args, ['-d', rhubarb#json_generate(options.data)])
  elseif has_key(options, 'data')
    call extend(args, ['-d', options.data])
  endif
  call add(args, a:path =~# '://' ? a:path : 'https://api.github.com'.a:path)
  return args
endfunction

function! rhubarb#request(path, ...) abort
  if !executable('curl')
    call s:throw('cURL is required')
  endif
  let options = a:0 ? a:1 : {}
  let args = s:curl_arguments(a:path, options)
  let raw = system('curl '.join(map(copy(args), 's:shellesc(v:val)'), ' '))
  if raw ==# ''
    return raw
  else
    return rhubarb#json_parse(raw)
  endif
endfunction

function! rhubarb#repo_request(...) abort
  let base = s:repo_homepage()
  if base =~# '//github\.com/'
    let base = substitute(base, '//github\.com/', '//api.github.com/repos/', '')
  else
    let base = substitute(base, '//[^/]\+/\zs', 'api/v3/repos/', '')
  endif
  return rhubarb#request(base . (a:0 && a:1 !=# '' ? '/' . a:1 : ''), a:0 > 1 ? a:2 : {})
endfunction

" }}}1
" Issues {{{1

function! rhubarb#omnifunc(findstart,base) abort
  if a:findstart
    let existing = matchstr(getline('.')[0:col('.')-1],'#\d*$\|@[[:alnum:]-]*$')
    return col('.')-1-strlen(existing)
  endif
  try
    if a:base =~# '^@'
      return map(rhubarb#repo_request('collaborators'), '"@".v:val.login')
    else
      let prefix = (a:base =~# '^#' ? '#' : s:repo_homepage().'/issues/')
      return map(rhubarb#repo_request('issues'), '{"word": prefix.v:val.number, "menu": v:val.title, "info": substitute(v:val.body,"\\r","","g")}')
    endif
  catch /^\%(fugitive\|rhubarb\):/
    return v:errmsg
  endtry
endfunction

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

" }}}1

" vim:set sw=2 sts=2:
