-- Downloads the official zsh source tarball and builds it into install_path.
--
-- Build notes (all three steps are required; skipping any one fails):
--   1. `Util/preconfig` must run before `autoconf` -- the git tree ships no
--      `configure`, only the autoconf sources.
--   2. `./configure --prefix=<install_path>` so the binary resolves its own
--      function/config paths relative to the mise install, not /usr.
--   3. `make install.install` rather than plain `make install`: it skips the
--      man pages and info docs, which is both much faster and the only target
--      that reliably succeeds without docutils/texinfo present.
function PLUGIN:BackendInstall(ctx)
    local cmd = require("cmd")
    local file = require("file")

    local version = ctx.version
    local install_path = ctx.install_path
    local download_path = ctx.download_path

    if RUNTIME.osType ~= "linux" and RUNTIME.osType ~= "darwin" then
        error("zsh-src only builds on linux and darwin, not " .. tostring(RUNTIME.osType))
    end

    local url = "https://github.com/zsh-users/zsh/archive/refs/tags/zsh-" .. version .. ".tar.gz"

    file.mkdirp(ctx.download_path)
    file.mkdirp(install_path)

    cmd.exec("curl --fail --location --silent --show-error --output \"$MISE_PLUGIN_TARBALL\" \"$MISE_PLUGIN_URL\"", {
        env = {
            MISE_PLUGIN_URL = url,
            MISE_PLUGIN_TARBALL = file.join_path(download_path, "zsh.tar.gz"),
        },
    })

    local src = file.join_path(download_path, "src")
    file.rmdir(src)
    file.mkdirp(src)
    cmd.exec("tar -xzf \"$MISE_PLUGIN_TARBALL\" -C \"$MISE_PLUGIN_SRC\" --strip-components=1", {
        env = { MISE_PLUGIN_TARBALL = file.join_path(download_path, "zsh.tar.gz"), MISE_PLUGIN_SRC = src },
    })

    cmd.exec("./Util/preconfig && autoconf", { cwd = src })
    cmd.exec("./configure --prefix=\"$MISE_PLUGIN_PREFIX\"", {
        cwd = src,
        env = { MISE_PLUGIN_PREFIX = install_path },
    })
    cmd.exec("make -j\"$(nproc)\"", { cwd = src })
    cmd.exec("make install.install", { cwd = src })

    local bin = file.join_path(install_path, "bin", "zsh")
    if not file.exists(bin) then
        error("build finished but " .. bin .. " is missing")
    end

    file.rmdir(download_path)

    return {}
end