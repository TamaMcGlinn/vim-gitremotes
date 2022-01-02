let s:actions = get(g:, 'gitremote_actions', {
  \ 'delete': function('gitremotes#Delete'), 
  \ 'add copy': function('gitremotes#Add_Copy'),
  \ 'edit': function('gitremotes#Edit') })

let s:keybinds = get(g:, 'gitremote_keybinds', { 
  \ 'ctrl-d': 'delete',
  \ 'ctrl-a': 'add copy',
  \ 'ctrl-e': 'edit' })

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

function! gitremotes#Add_Copy(lines) abort
  if len(a:lines) != 1
    throw "Can only add copy of one remote"
  endif
  let l:remote = gitremotes#Split_Remote_Line(a:lines[0])
  let l:new_name = input('Name> ', l:remote[0])
  if l:new_name == l:remote[0]
    throw "You must specify a new name for the remote. Use edit to change only the url."
  endif
  if s:remote_exists(l:new_name)
    throw "A remote named " . l:new_name . " already exists"
  endif
  let l:url = input('URL> ', l:remote[1])
  execute ':GRemoteAdd ' . l:new_name . ' ' . l:url
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
  let l:new_name = input('Name> ', l:remote[0])
  let l:url = input('URL> ', l:remote[1])
  execute ':GRemoteEdit ' . l:remote[0] . ' ' l:new_name . ' ' . l:url
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
    return join(map(items(s:keybinds), 'toupper(v:val[0]) . " to " . v:val[1]'), ', ')
endfunction
