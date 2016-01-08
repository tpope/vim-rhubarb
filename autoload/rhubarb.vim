" Location: autoload/rhubarb.vim
" Author: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_rhubarb')
  finish
endif
let g:autoloaded_rhubarb = 1

" Section: Utility

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

function! rhubarb#homepage_for_url(url) abort
  let domain_pattern = 'github\.com'
  let domains = get(g:, 'github_enterprise_urls', get(g:, 'fugitive_github_domains', []))
  call map(copy(domains), 'substitute(v:val, "/$", "", "")')
  for domain in domains
    let domain_pattern .= '\|' . escape(split(domain, '://')[-1], '.')
  endfor
  let base = matchstr(a:url, '^\%(https\=://\|git://\|git@\)\=\zs\('.domain_pattern.'\)[/:].\{-\}\ze\%(\.git\)\=$')
  if index(domains, 'http://' . matchstr(base, '^[^:/]*')) >= 0
    return 'http://' . tr(base, ':', '/')
  elseif !empty(base)
    return 'https://' . tr(base, ':', '/')
  else
    return ''
  endif
endfunction

function! s:repo_homepage() abort
  if exists('b:rhubarb_homepage')
    return b:rhubarb_homepage
  endif
  let repo = fugitive#repo()
  let homepage = rhubarb#homepage_for_url(repo.config('remote.origin.url'))
  if !empty(homepage)
    let b:rhubarb_homepage = homepage
    return b:rhubarb_homepage
  endif
  call s:throw('origin is not a GitHub repository')
endfunction

" Section: HTTP

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
    call extend(args, has('win32') && filereadable(expand('~/.netrc'))
          \ ? ['--netrc-file', expand('~/.netrc')] : ['--netrc'])
  endif
  if has_key(options, 'method')
    call extend(args, ['-X', toupper(options.method)])
  endif
  for header in get(options, 'headers', [])
    call extend(args, ['-H', header])
  endfor
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

" Section: Issues

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
      let issues = rhubarb#repo_request('issues')
      if type(issues) == type({})
        call s:throw(get(issues, 'message', 'unknown error'))
      endif
      return map(issues, '{"word": prefix.v:val.number, "menu": v:val.title, "info": substitute(v:val.body,"\\r","","g")}')
    endif
  catch /^\%(fugitive\|rhubarb\):/
    echoerr v:errmsg
  endtry
endfunction

" Section: Fugitive :Gbrowse support

function! rhubarb#fugitive_url(opts, ...) abort
  if a:0 || type(a:opts) != type({}) || !has_key(a:opts, 'repo')
    return ''
  endif
  let root = rhubarb#homepage_for_url(get(a:opts, 'remote'))
  if empty(root)
    return ''
  endif
  let path = substitute(a:opts.path, '^/', '', '')
  if path =~# '^\.git/refs/heads/'
    let branch = a:opts.repo.git_chomp('config','branch.'.path[16:-1].'.merge')[11:-1]
    if branch ==# ''
      return root . '/commits/' . path[16:-1]
    else
      return root . '/commits/' . branch
    endif
  elseif path =~# '^\.git/refs/tags/'
    return root . '/releases/tag/' . path[15:-1]
  elseif path =~# '^\.git/refs/remotes/[^/]\+/.'
    return root . '/commits/' . matchstr(path,'remotes/[^/]\+/\zs.*')
  elseif path =~# '.git/\%(config$\|hooks\>\)'
    return root . '/admin'
  elseif path =~# '^\.git\>'
    return root
  endif
  if a:opts.commit =~# '^\d\=$'
    let commit = a:opts.repo.rev_parse('HEAD')
  else
    let commit = a:opts.commit
  endif
  if get(a:opts, 'type', '') ==# 'tree' || a:opts.path =~# '/$'
    let url = substitute(root . '/tree/' . commit . '/' . path, '/$', '', 'g')
  elseif get(a:opts, 'type', '') ==# 'blob' || a:opts.path =~# '[^/]$'
    let url = root . '/blob/' . commit . '/' . path
    if get(a:opts, 'line2') && a:opts.line1 == a:opts.line2
      let url .= '#L' . a:opts.line1
    elseif get(a:opts, 'line2')
      let url .= '#L' . a:opts.line1 . '-L' . a:opts.line2
    endif
  else
    let url = root . '/commit/' . commit
  endif
  return url
endfunction
