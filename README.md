# Git remote manager

A small vim plugin to manage git remotes. This plugin is inspired by [fzf.vim](https://github.com/junegunn/fzf.vim), using [fzf](https://github.com/junegunn/fzf) for its UI to make git remote management simple.

### Features

* Adds a useful interface for managing remotes, including removing, renaming, changing the url and creating a copy
* Matches both vim-fugitive and fzf.vim in design so that it will feel familiar to anyone who already uses them

### Dependencies

This plugin depends on fzf for it's UI. Other than that, almost any version of vim (or neovim) and git should work with this plugin.
You must also have [vim-fugitive](https://github.com/tpope/vim-fugitive) installed.

### Installation

Using [vim-plug](https://github.com/junegunn/vim-plug), it's as simple as:

`Plug 'TamaMcGlinn/vim-git-remotes'`

### Usage

This plugin exposes commands for you to use or bind as you see fit:
* `GRemotesList` -- Opens an fzf window with a list of all git remotes. This list gives the users a couple of options to manage their stashes
  * `ctrl-a` -- Adds a copy of the remote for you to edit.
  * `ctrl-d` -- Deletes the remote(s). You can mark multiple remotes for deletion with the `tab` key.
  * `ctrl-e` -- Edit the remote(s). Prompts for optional new name, and optional new url.
  * `ctrl-s` -- TODO implement this one. Toggles the remote between SSH and HTTPS url.
  * `ctrl-f` -- TODO implement this one. Add a fork (specify only the changed username in a github url)
* `GRemoteAdd [name] [url]` -- Adds a remote.
* `GRemoteEdit [name] [new_name] [url]` -- Change name and/or url of a remote. Also accessible from the fzf window, no need to bind directly.

### Configuration

Example bindings for your vimrc:

```
" note trailing space after GRemoteAdd
nnoremap <leader>gra :GRemoteAdd 
nnoremap <leader>grr :GRemoteList<CR>
```

### Advanced configuration

The plugin allows configuring the actions and keybindings that are available in the stash list (opened with `GRemotesList`):

```
" The default configuration
let g:gitremote_actions = {
  \ 'delete': function('gitremotes#Delete'), 
  \ 'add copy': function('gitremotes#Add_Copy'),
  \ 'edit': function('gitremotes#Edit') })

let g:gitremote_keybinds = {
  \ 'ctrl-d': 'delete',
  \ 'ctrl-a': 'add copy',
  \ 'ctrl-e': 'edit' })
```

You can add your own keybindings and commands. Each such function accepts one parameter, a list of strings of the form 'name	url (fetch/push)', each of which can be passed to gitremotes#Split_Remote_Line to get a list of two strings, the name and the url.
