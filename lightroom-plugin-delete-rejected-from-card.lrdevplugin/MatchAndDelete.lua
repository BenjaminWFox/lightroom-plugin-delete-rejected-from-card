local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"

local MatchAndDelete = {}

local SIDECAR_EXTENSIONS = {
    "xmp",
    "dop",
    "pp3",
    "thm",
    "wav",
}

local function appendUniquePath(path, list, seen)
    if path and path ~= "" and not seen[path] then
        seen[path] = true
        list[#list + 1] = path
    end
end

function MatchAndDelete.expandDeleteTargets(matchedPaths)
    local targets = {}
    local seen = {}

    for _, matchedPath in ipairs(matchedPaths or {}) do
        appendUniquePath(matchedPath, targets, seen)

        local stem = LrPathUtils.removeExtension(matchedPath)
        if stem and stem ~= "" then
            for _, extension in ipairs(SIDECAR_EXTENSIONS) do
                local sidecarPath = stem .. "." .. extension
                if LrFileUtils.exists(sidecarPath) == "file" then
                    appendUniquePath(sidecarPath, targets, seen)
                end
            end
        end
    end

    return targets
end

function MatchAndDelete.deleteMatches(args)
    local matchedPaths = args.matchedPaths or {}
    local progressScope = args.progressScope

    local deleteTargets = MatchAndDelete.expandDeleteTargets(matchedPaths)
    local deletedPaths = {}
    local skippedPaths = {}
    local failedPaths = {}
    local total = #deleteTargets

    if total == 0 then
        return {
            canceled = false,
            deletedPaths = {},
            skippedPaths = {},
            failedPaths = {},
            attemptedCount = 0,
            totalDeleteTargets = 0,
        }
    end

    for index, path in ipairs(deleteTargets) do
        if progressScope and progressScope:isCanceled() then
            return {
                canceled = true,
                deletedPaths = deletedPaths,
                skippedPaths = skippedPaths,
                failedPaths = failedPaths,
                attemptedCount = index - 1,
                totalDeleteTargets = total,
            }
        end

        if progressScope then
            progressScope:setCaption(string.format("Deleting file %d/%d:\n%s", index, total, path))
            progressScope:setPortionComplete(index - 1, total)
        end

        local existsKind = LrFileUtils.exists(path)
        if existsKind ~= "file" then
            skippedPaths[#skippedPaths + 1] = {
                path = path,
                reason = "Path no longer exists.",
            }
        elseif not LrFileUtils.isDeletable(path) then
            skippedPaths[#skippedPaths + 1] = {
                path = path,
                reason = "Path is not deletable.",
            }
        else
            local success, errorMessage = LrFileUtils.delete(path)
            if success then
                deletedPaths[#deletedPaths + 1] = path
            else
                failedPaths[#failedPaths + 1] = {
                    path = path,
                    reason = errorMessage or "Unknown delete error.",
                }
            end
        end

        if index % 50 == 0 then
            LrTasks.yield()
        end
    end

    if progressScope and total > 0 then
        progressScope:setPortionComplete(total, total)
    end

    return {
        canceled = false,
        deletedPaths = deletedPaths,
        skippedPaths = skippedPaths,
        failedPaths = failedPaths,
        attemptedCount = total,
        totalDeleteTargets = total,
    }
end

return MatchAndDelete
