-- Lists the tools this backend manages. mise prefixes each returned name with
-- the plugin name, so this makes `zsh-src:zsh` show up in `mise search`.
function PLUGIN:BackendListTools(ctx)
    return { tools = { "zsh" } }
end