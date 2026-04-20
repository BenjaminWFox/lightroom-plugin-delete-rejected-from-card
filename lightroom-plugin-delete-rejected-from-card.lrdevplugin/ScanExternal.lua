local LrFileUtils = import "LrFileUtils"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"

local ScanExternal = {}

local function isDirectory(path)
    return LrFileUtils.exists(path) == "directory"
end

local function collectChildDirectories(path)
    local childDirectories = {}
    for childPath in LrFileUtils.directoryEntries(path) do
        if isDirectory(childPath) then
            childDirectories[#childDirectories + 1] = childPath
        end
    end
    return childDirectories
end

function ScanExternal.collectMatches(args)
    local externalRootPath = args.externalRootPath
    local rejectedFileNames = args.rejectedFileNames or {}
    local progressScope = args.progressScope

    if LrFileUtils.exists(externalRootPath) ~= "directory" then
        return {
            errorMessage = "Selected external root is not a readable directory:\n" .. externalRootPath,
        }
    end

    local matchedPaths = {}
    local seenPaths = {}
    local filesScanned = 0
    local directoriesScanned = 0
    local stack = { externalRootPath }

    while #stack > 0 do
        if progressScope and progressScope:isCanceled() then
            return { canceled = true }
        end

        local currentDirectory = table.remove(stack)
        directoriesScanned = directoriesScanned + 1

        if progressScope then
            progressScope:setCaption(string.format("Scanning external media (%d dirs, %d files):\n%s", directoriesScanned, filesScanned, currentDirectory))
        end

        for filePath in LrFileUtils.files(currentDirectory) do
            if progressScope and progressScope:isCanceled() then
                return { canceled = true }
            end

            filesScanned = filesScanned + 1
            local leafName = LrPathUtils.leafName(filePath)
            if leafName and rejectedFileNames[leafName] and not seenPaths[filePath] then
                seenPaths[filePath] = true
                matchedPaths[#matchedPaths + 1] = filePath
            end

            if filesScanned % 200 == 0 then
                LrTasks.yield()
            end
        end

        local childDirectories = collectChildDirectories(currentDirectory)
        for _, childDirectory in ipairs(childDirectories) do
            stack[#stack + 1] = childDirectory
        end
    end

    return {
        matchedPaths = matchedPaths,
        filesScanned = filesScanned,
        directoriesScanned = directoriesScanned,
    }
end

return ScanExternal
