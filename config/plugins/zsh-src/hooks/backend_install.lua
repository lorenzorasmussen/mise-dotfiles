-- Downloads the official zsh source tarball and builds it into install_path.
--
-- Build notes (all three steps are required; skipping any one fails):
--   1. `Util/preconfig` must run before `autoconf` -- the git tree ships no
--      `configure`, only the autoconf sources.
--   2. `./configure --prefix=<install_path>` so the binary resolves its own
--      fpath relative to the mise install rather than /usr.
--   3. Install with the explicit sub-targets. There is NO `install.install` in
--      zsh's Makefile.in -- verified against the zsh-5.9.2 tarball, the
--      available targets are install.bin, install.modules, install.fns,
--      install.runhelp, install.man, install.info, install.html.
--      * install.man is left out: it builds man pages with yodl/texinfo, which
--        is not installed and not needed for completions.
--      * install.runhelp is left out too, and not only for speed: it runs in
--        Doc/ and shells out to `git describe`, which fails hard on a tarball
--        ("fatal: not a git repository") because mise downloads the archive
--        rather than cloning. That failure aborts the whole install.
--      The remaining three are what a working shell needs: the binary, the
--      zsh/zmodload.h module header, and the shell functions (Completion/
--      lives in the fpath install).
--
-- The `file` module has no mkdir/remove (only join_path, read, symlink,
-- exists, list, glob, move, stat), so directory creation and the download
-- scratch dir go through cmd.exec. This hook is linux/darwin only -- it rejects
-- every other osType before reaching shell code.
function PLUGIN:BackendInstall(ctx)
    local cmd = require("cmd")
    local file = require("file")
    local http = require("http")
    local archiver = require("archiver")

    local version = ctx.version
    local install_path = ctx.install_path
    local download_path = ctx.download_path

    if RUNTIME.osType ~= "linux" and RUNTIME.osType ~= "darwin" then
        error("zsh-src only builds on linux and darwin, not " .. tostring(RUNTIME.osType))
    end

    local url = "https://github.com/zsh-users/zsh/archive/refs/tags/zsh-" .. version .. ".tar.gz"

    cmd.exec("mkdir -p \"$MISE_ZSH_DL\" \"$MISE_ZSH_SRC\" \"$MISE_ZSH_PREFIX\"", {
        env = {
            MISE_ZSH_DL = download_path,
            MISE_ZSH_SRC = file.join_path(download_path, "src"),
            MISE_ZSH_PREFIX = install_path,
        },
    })

    local tarball = file.join_path(download_path, "zsh.tar.gz")
    http.download_file({ url = url }, tarball)
    if not file.exists(tarball) then
        error("download reported success but " .. tarball .. " is missing")
    end

    archiver.decompress(tarball, file.join_path(download_path, "src"), { strip_components = 1 })

    cmd.exec("./Util/preconfig && autoconf", { cwd = file.join_path(download_path, "src") })
    cmd.exec("./configure --prefix=\"$MISE_ZSH_PREFIX\"", {
        cwd = file.join_path(download_path, "src"),
        env = { MISE_ZSH_PREFIX = install_path },
    })
    cmd.exec("make -j\"$(nproc)\"", { cwd = file.join_path(download_path, "src") })
    cmd.exec("make install.bin install.modules install.fns", {
        cwd = file.join_path(download_path, "src"),
    })

    local bin = file.join_path(install_path, "bin", "zsh")
    if not file.exists(bin) then
        error("build finished but " .. bin .. " is missing")
    end

    cmd.exec("rm -rf \"$MISE_ZSH_DL\"", { env = { MISE_ZSH_DL = download_path } })

    return {}
end