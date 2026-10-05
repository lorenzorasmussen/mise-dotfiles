-- zsh resolves its function path relative to the configure --prefix, so the
-- only env entry mise needs is the install's bin/ on PATH. Without bin/ on
-- PATH, `zsh` is not runnable and none of the fpath completion wiring below
-- can be tested.
function PLUGIN:BackendExecEnv(ctx)
    local file = require("file")
    return {
        env_vars = {
            { key = "PATH", value = file.join_path(ctx.install_path, "bin") },
        },
    }
end