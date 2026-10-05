-- Lists zsh versions from the upstream git tags.
--
-- zsh tags release tarballs (`zsh-5.9.2`) *and* per-release test tags
-- (`zsh-5.9.1.2-test`). Only plain `zsh-X.Y[.Z]` is installable, so the
-- `-test` suffix is dropped here rather than filtered out downstream.
--
-- mise preserves the order returned by this hook and expects
-- oldest-to-newest. `git ls-remote` emits hash order, so the list is sorted
-- numerically below instead of relying on the order that came off the wire.
function PLUGIN:BackendListVersions(ctx)
    local cmd = require("cmd")

    local out = cmd.exec("git ls-remote --tags --refs " .. ZSH_REPO)

    local seen, versions = {}, {}
    for line in out:gmatch("[^\r\n]+") do
        local tag = line:match("refs/tags/(zsh%-.*)$")
        if tag then
            local version = tag:gsub("^zsh%-", "")
            -- Keep only plain numeric releases: reject "-test", "-rc1", etc.
            if version:match("^%d+%.%d+%.?%d*$") and not seen[version] then
                seen[version] = true
                table.insert(versions, version)
            end
        end
    end

    if #versions == 0 then
        error("no zsh tags parsed from " .. ZSH_REPO)
    end

    table.sort(versions, function(a, b)
        local pa, pb = {}, {}
        for n in a:gmatch("%d+") do table.insert(pa, tonumber(n)) end
        for n in b:gmatch("%d+") do table.insert(pb, tonumber(n)) end
        for i = 1, math.max(#pa, #pb) do
            local x, y = pa[i] or 0, pb[i] or 0
            if x ~= y then return x < y end
        end
        return false
    end)

    return { versions = versions }
end