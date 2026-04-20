local LrApplication = import "LrApplication"
local LrPathUtils = import "LrPathUtils"
local LrTasks = import "LrTasks"

local ScanRejected = {}

local function appendFolderTree(rootFolder, allFolders, progressScope)
    local stack = { rootFolder }

    while #stack > 0 do
        if progressScope and progressScope:isCanceled() then
            return false
        end

        local folder = table.remove(stack)
        allFolders[#allFolders + 1] = folder

        local children = folder:getChildren() or {}
        for _, child in ipairs(children) do
            stack[#stack + 1] = child
        end

        LrTasks.yield()
    end

    return true
end

function ScanRejected.collectRejectedFilenames(args)
    local sourceFolderPath = args.sourceFolderPath
    local recurseSource = args.recurseSource
    local progressScope = args.progressScope

    local catalog = LrApplication.activeCatalog()
    local sourceFolder = catalog:getFolderByPath(sourceFolderPath)
    if not sourceFolder then
        return {
            errorMessage = "Selected source folder is not in the Lightroom catalog:\n" .. sourceFolderPath,
        }
    end

    local folders = {}
    if recurseSource then
        if progressScope then
            progressScope:setCaption("Scanning Lightroom folder tree...")
        end
        local completed = appendFolderTree(sourceFolder, folders, progressScope)
        if not completed then
            return { canceled = true }
        end
    else
        folders[1] = sourceFolder
    end

    local rejectedSet = {}
    local rejectedCount = 0
    local photosInspected = 0
    local folderCount = #folders

    for folderIndex, folder in ipairs(folders) do
        if progressScope and progressScope:isCanceled() then
            return { canceled = true }
        end

        local folderPath = folder:getPath() or "<unknown>"
        if progressScope then
            progressScope:setCaption(string.format("Scanning catalog folder %d/%d:\n%s", folderIndex, folderCount, folderPath))
        end

        local photos = folder:getPhotos(false) or {}
        for _, photo in ipairs(photos) do
            if progressScope and progressScope:isCanceled() then
                return { canceled = true }
            end

            photosInspected = photosInspected + 1

            local pickStatus = photo:getRawMetadata("pickStatus")
            if pickStatus == -1 then
                local fileName = photo:getFormattedMetadata("fileName") or LrPathUtils.leafName(photo:getRawMetadata("path") or "")
                if fileName and fileName ~= "" then
                    if not rejectedSet[fileName] then
                        rejectedSet[fileName] = true
                    end
                    rejectedCount = rejectedCount + 1
                end
            end

            if photosInspected % 100 == 0 then
                LrTasks.yield()
            end
        end
    end

    return {
        rejectedFileNames = rejectedSet,
        rejectedCount = rejectedCount,
        uniqueRejectedCount = (function()
            local count = 0
            for _ in pairs(rejectedSet) do
                count = count + 1
            end
            return count
        end)(),
        photosInspected = photosInspected,
        foldersScanned = folderCount,
    }
end

return ScanRejected
