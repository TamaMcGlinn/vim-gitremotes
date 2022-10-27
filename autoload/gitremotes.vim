let s:actions = get(g:, 'gitremote_actions', {
  \ 'delete': function('gitremotes#Delete'), 
  \ 'add copy': function('gitremotes#Add_Copy'),
  \ 'add fork': function('gitremotes#Add_Fork'),
  \ 'push': function('gitremotes#Push_To'),
  \ 'force push': function('gitremotes#Force_Push_To'),
  \ 'fetch': function('gitremotes#Fetch_From'),
  \ 'pull': function('gitremotes#Pull_From'),
  \ 'swap ssh/https': function('gitremotes#Swap_SSH_HTTPS'),
  \ 'edit': function('gitremotes#Edit') })

let s:keybinds = get(g:, 'gitremote_keybinds', { 
  \ 'ctrl-d': 'delete',
  \ 'ctrl-a': 'add copy',
  \ 'ctrl-f': 'add fork',
  \ 'ctrl-k': 'push',
  \ 'ctrl-i': 'force push',
  \ 'ctrl-j': 'fetch',
  \ 'ctrl-u': 'pull',
  \ 'ctrl-s': 'swap ssh/https',
  \ 'ctrl-e': 'edit' })

let s:username = get(g:, 'gitremote_username', '')

function! s:list_contains(list, item) abort
  return index(a:list, a:item) >= 0
endfunction

function! gitremotes#Split_Remote_Line(line) abort
  let l:remote_name = matchstr(a:line, '^[^	]*')
  let l:remote_url = substitute(substitute(a:line, '^[^	]*	', '', ''), '\s([^)]*)$', '', '')
  return [l:remote_name, l:remote_url]
endfunction

function! gitremotes#Delete(lines) abort
  let l:removed_remotes = []
  for idx in range(len(a:lines))
      let l:remote_name = gitremotes#Split_Remote_Line(a:lines[l:idx])[0]
      if !s:list_contains(l:removed_remotes, l:remote_name)
        call gitremotes#Remove_Remote(l:remote_name)
        call add(l:removed_remotes, l:remote_name)
      endif
  endfor
endfunction

function! gitremotes#Remove_Remote(remote_name) abort
  if empty(a:remote_name)
    throw 'Tried to delete remote with no name'
  endif
  let l:full_command = FugitiveShellCommand() . ' remote remove ' . a:remote_name
  call s:checked_shell(l:full_command)
endfunction

function! s:remote_exists(remote_name) abort
  let l:remotes_list = s:get_remotes()
  call map(l:remotes_list, "gitremotes#Split_Remote_Line(v:val)[0]")
  return index(l:remotes_list, a:remote_name) >= 0
endfunction

function! s:get_new_remote_name(default_name) abort
  let l:new_name = input('Name> ', a:default_name)
  if l:new_name == a:default_name
    throw "You must specify a new name for the remote. Use edit to change only the url."
  endif
  if s:remote_exists(l:new_name)
    throw "A remote named " . l:new_name . " already exists"
  endif
  return l:new_name
endfunction

function! gitremotes#Add_Copy(lines) abort
  if len(a:lines) != 1
    throw "Can only add copy of one remote"
  endif
  let l:remote = gitremotes#Split_Remote_Line(a:lines[0])
  let l:new_name = s:get_new_remote_name(l:remote[0])
  let l:new_url = input('URL> ', l:remote[1])
  execute ':GRemoteAdd ' . l:new_name . ' ' . l:new_url
endfunction

function! s:replace_username_in_url(url, new_username) abort
  " SSH address, e.g. git@github.com:TamaMcGlinn/vim-gitremotes
  let l:new_url = substitute(a:url, '^\(git@[^:]*:\)[^/]*', '\1' . a:new_username, '')
  " HTTP(S) address, e.g. https://github.com/TamaMcGlinn/vim-gitremotes.git
  let l:new_url = substitute(l:new_url, '^\(https\?://[^/]*/\)[^/]*', '\1' . a:new_username, '')
  return l:new_url
endfunction

function! gitremotes#Add_Fork(lines) abort
  if len(a:lines) != 1
    throw "Can only add fork of one remote"
  endif
  let l:remote = gitremotes#Split_Remote_Line(a:lines[0])
  let l:new_name = s:get_new_remote_name(l:remote[0])
  " normally, the name we pick for the remote equals the username
  " so we give that as the default when prompting the user
  let l:default_username = l:new_name
  if exists("g:gitremote_username") && count(['origin', 'fork', 'upstream', 'downstream'], l:new_name) > 0
    " but when adding some common names we probably want to use our own github username
    let l:default_username = g:gitremote_username
  endif
  let l:new_user = input('User> ', l:default_username)
  let l:new_url = s:replace_username_in_url(l:remote[1], l:new_user)
  execute ':GRemoteAdd ' . l:new_name . ' ' . l:new_url
endfunction

function! s:remote_command(lines, command)
  for idx in range(len(a:lines))
    let l:remote_name = gitremotes#Split_Remote_Line(a:lines[l:idx])[0]
    call s:checked_shell(FugitiveShellCommand() . a:command . l:remote_name)
  endfor
endfunction

function! gitremotes#Push_To(lines) abort
  call s:remote_command(a:lines, ' push ')
endfunction

function! gitremotes#Force_Push_To(lines) abort
  call s:remote_command(a:lines, ' push --force-with-lease ')
endfunction

function! gitremotes#Fetch_From(lines) abort
  call s:remote_command(a:lines, ' fetch ')
endfunction

function! gitremotes#Pull_From(lines) abort
  call s:remote_command(a:lines, ' pull ')
endfunction

function! gitremotes#Swap_SSH_HTTPS(lines) abort
  for idx in range(len(a:lines))
    let l:remote = gitremotes#Split_Remote_Line(a:lines[l:idx])
    let l:remote_name = l:remote[0]
    let l:remote_url = l:remote[1]
    if l:remote_url =~# '^git@'
      " SSH address, e.g. git@github.com:TamaMcGlinn/vim-gitremotes
      let l:new_url = substitute(l:remote_url, '^git@\([^:]*\):\(.*\)', 'https://\1/\2', '')
    elseif l:remote_url =~# '^https\?://'
      " HTTP(S) address, e.g. https://github.com/TamaMcGlinn/vim-gitremotes.git
      let l:new_url = substitute(l:remote_url, '^https\?://\([^/]*\)/\(.*\)', 'git@\1:\2', '')
    else
      throw "Couldn't recognise url " . l:remote_url . " as either SSH or HTTPS."
    endif
    call gitremotes#edit_remote(l:remote_name, l:remote_name, l:new_url)
  endfor
endfunction

function! s:remote_sink(lines) abort
    if len(a:lines) < 2 || empty(a:lines[0])
        return
    endif
    let l:keybind = get(s:keybinds, a:lines[0], v:null)
    if l:keybind is v:null
      throw "Could not find keybind " . a:lines[0]
    endif
    let l:marked_remotes = a:lines[1:-1]
    let l:Action = get(s:actions, l:keybind, v:null)
    if l:Action is v:null
      throw "Could not find an action corresponding to " . l:keybind
    endif
    call l:Action(l:marked_remotes)
endfunction

function! s:checked_shell(cmd) abort
    let l:output=system(a:cmd)
    if v:shell_error
      throw l:output
    endif
endfunction

function! gitremotes#create_remote(name, url) abort
    call s:checked_shell(FugitiveShellCommand() . ' remote add '.a:name.' '.a:url)
endfunction

function! gitremotes#Edit(lines) abort
  if len(a:lines) != 1
    throw "Can only edit one remote"
  endif
  let l:remote = gitremotes#Split_Remote_Line(a:lines[0])
  " Note: not using s:get_new_remote_name, because this name may be the same
  " as the current one
  let l:new_name = input('Name> ', l:remote[0])
  let l:url = input('URL> ', l:remote[1])
  call gitremotes#edit_remote(l:remote[0], l:new_name, l:url)
endfunction

function! gitremotes#edit_remote(name, new_name, new_url) abort
    call gitremotes#Remove_Remote(a:name)
    call gitremotes#create_remote(a:new_name, a:new_url)
endfunction

function! s:get_remotes() abort
  let l:remotes_list = systemlist(FugitiveShellCommand() . ' remote -v')
  call filter(l:remotes_list, "v:val =~ '.*(fetch)'")
  call map(l:remotes_list, "substitute(v:val, ' (fetch)', '', '')")
  return l:remotes_list
endfunction

function! gitremotes#list_remotes(...) abort
    let l:remotes_list = s:get_remotes()
    let l:expect_keys = join(keys(s:keybinds), ',')
    let l:help_text = s:get_keybinding_description()
    let l:options = {
    \ 'source': l:remotes_list,
    \ 'sink*': function('s:remote_sink'),
    \ 'options': ['--ansi', '--multi', '--tiebreak=index', '--reverse',
    \   '--inline-info', '--prompt', 'Remotes> ', '--header',
    \   ':: ' . l:help_text, '--expect='.l:expect_keys]
    \ }
    return fzf#run(fzf#wrap("", l:options, 0))
endfunction

function! s:get_keybinding_description()
    return join(map(items(s:keybinds), 'toupper(v:val[0]) . ": " . v:val[1]'), ', ')
endfunction
