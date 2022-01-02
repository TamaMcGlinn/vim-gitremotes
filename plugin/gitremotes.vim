command! -nargs=* GRemoteAdd call gitremotes#create_remote(<f-args>)
command! -nargs=* GRemoteEdit call gitremotes#edit_remote(<f-args>)
command!          GRemoteList call gitremotes#list_remotes(<q-args>)

