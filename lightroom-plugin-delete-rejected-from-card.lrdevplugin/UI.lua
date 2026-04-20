local LrApplication = import "LrApplication"
local LrDialogs = import "LrDialogs"

local MatchAndDelete = require "MatchAndDelete"

local UI = {}

local function getSingleActiveFolderPath()
    local catalog = LrApplication.activeCatalog()
    local activeSources = catalog:getActiveSources() or {}

    if #activeSources ~= 1 then
        return nil
    end

    local source = activeSources[1]
    if source and source.type and source.getPath and source:type() == "LrFolder" then
        return source:getPath()
    end

    return nil
end

local function chooseFolder(title, prompt)
    local result = LrDialogs.runOpenPanel({
        title = title,
        prompt = prompt,
        canChooseFiles = false,
        canChooseDirectories = true,
        canCreateDirectories = false,
        allowsMultipleSelection = false,
    })

    if not result or #result == 0 then
        return nil
    end

    return result[1]
end

local function renderPathSamples(paths, maxItems)
    local limit = maxItems or 12
    local lines = {}
    local count = #paths

    for i = 1, math.min(limit, count) do
        lines[#lines + 1] = paths[i]
    end

    if count > limit then
        lines[#lines + 1] = string.format("... and %d more", count - limit)
    end

    if #lines == 0 then
        return "(no matches)"
    end

    return table.concat(lines, "\n")
end

function UI.promptSourceSelection()
    local sourceFolderPath = getSingleActiveFolderPath()
    if not sourceFolderPath then
        sourceFolderPath = chooseFolder(
            "Choose Lightroom Catalog Source Folder",
            "Use This Catalog Folder"
        )
    else
        local useActive = LrDialogs.confirm(
            "Use currently selected Lightroom folder?",
            "Selected source in Library Folders panel:\n" .. sourceFolderPath .. "\n\nChoose 'Use Selected Lightroom Folder' to continue, or 'Choose Folder with Rejected Images' to open a picker.",
            "Use Selected Lightroom Folder",
            "Cancel",
            "Choose Folder with Rejected Images"
        )

        if useActive == "cancel" then
            return nil
        end

        if useActive == "other" then
            sourceFolderPath = chooseFolder(
                "Choose Lightroom Catalog Source Folder",
                "Use This Catalog Folder"
            )
        end
    end

    if not sourceFolderPath then
        return nil
    end

    local recurseChoice = LrDialogs.confirm(
        "Scan subfolders in Lightroom source?",
        "Choose 'Recurse' for full subtree scan (cancelable with progress UI), or 'Top-level only' for faster scanning.",
        "Recurse",
        "Cancel",
        "Top-level only"
    )

    if recurseChoice == "cancel" then
        return nil
    end

    return {
        sourceFolderPath = sourceFolderPath,
        recurseSource = recurseChoice == "ok",
    }
end

function UI.promptExternalRoot()
    return chooseFolder(
        "Choose External Drive/Card Root",
        "Use External Root"
    )
end

function UI.promptDeleteConfirmation(args)
    local matchedPaths = args.matchedPaths or {}
    local deleteTargets = MatchAndDelete.expandDeleteTargets(matchedPaths)

    if #matchedPaths == 0 then
        LrDialogs.message(
            "No matching files found",
            "No filename matches were found on the selected external root.",
            "info"
        )
        return { confirmed = false, reason = "no_matches" }
    end

    local src = args.sourceFolderPath or ""
    local ext = args.externalRootPath or ""

    local detail = string.format(
        "Filename-only matching (duplicate names can collide).\n\n"
            .. "Rejected in source: %d\n"
            .. "Matched on external media: %d\n"
            .. "Delete targets including sidecars (.xmp, .dop, .pp3, .thm, .wav): %d\n\n"
            .. "This permanently deletes files on the external volume only (not the Lightroom catalog).\n\n"
            .. "Source folder:\n%s\n\n"
            .. "External root:\n%s\n\n"
            .. "Sample matched paths:\n%s",
        args.rejectedCount or 0,
        #matchedPaths,
        #deleteTargets,
        src,
        ext,
        renderPathSamples(matchedPaths, 8)
    )

    local quickConfirm = LrDialogs.confirm(
        "Review before permanent delete",
        detail,
        "Continue",
        "Cancel"
    )

    if quickConfirm == "ok" then
        return { confirmed = true }
    end

    return { confirmed = false, reason = "cancel" }
end

function UI.showFinalReport(deleteResult)
    if not deleteResult then
        LrDialogs.message(
            "Delete failed",
            "No delete result was returned.",
            "critical"
        )
        return
    end

    local deletedCount = #(deleteResult.deletedPaths or {})
    local skippedCount = #(deleteResult.skippedPaths or {})
    local failedCount = #(deleteResult.failedPaths or {})

    if deleteResult.canceled then
        LrDialogs.message(
            "Delete canceled",
            string.format(
                "Operation canceled.\nDeleted: %d\nSkipped: %d\nFailed: %d",
                deletedCount,
                skippedCount,
                failedCount
            ),
            "warning"
        )
        return
    end

    local details = {
        string.format("Deleted: %d", deletedCount),
        string.format("Skipped: %d", skippedCount),
        string.format("Failed: %d", failedCount),
    }

    local function appendIssues(label, items)
        if not items or #items == 0 then
            return
        end
        details[#details + 1] = ""
        details[#details + 1] = label
        for i = 1, math.min(12, #items) do
            local item = items[i]
            if type(item) == "table" then
                details[#details + 1] = string.format("- %s (%s)", item.path or "unknown", item.reason or "no reason")
            else
                details[#details + 1] = string.format("- %s", item)
            end
        end
    end

    appendIssues("Skipped sample:", deleteResult.skippedPaths)
    appendIssues("Failures sample:", deleteResult.failedPaths)

    LrDialogs.message(
        "Delete rejected from card - complete",
        table.concat(details, "\n"),
        failedCount > 0 and "warning" or "info"
    )
end

return UI
