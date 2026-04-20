local LrDialogs = import "LrDialogs"
local LrFunctionContext = import "LrFunctionContext"
local LrTasks = import "LrTasks"

local ScanRejected = require "ScanRejected"
local ScanExternal = require "ScanExternal"
local MatchAndDelete = require "MatchAndDelete"
local UI = require "UI"

--[[
    showModalProgressDialog(functionContext = X) ties the modal's lifetime to X.
    Using the outer runWorkflow context meant the modal would not fully release
    until the entire workflow finished (after confirm + delete), which can leave
    a stuck "Task completed" / Cancel UI and lock up Lightroom.

    Each blocking progress phase runs in its own short lived callWithContext so
    the modal's context ends immediately after progressScope:done().
]]
local function runWorkflow()
    local sourceSelection = UI.promptSourceSelection()
    if not sourceSelection then
        return
    end

    local externalRootPath = UI.promptExternalRoot()
    if not externalRootPath then
        return
    end

    local rejectedResult
    local externalResult

    LrFunctionContext.callWithContext("DeleteRejectedFromCard.Scan", function(scanContext)
        local progressScope = LrDialogs.showModalProgressDialog({
            title = "Delete rejected from card",
            caption = "Preparing scan...",
            cannotCancel = false,
            functionContext = scanContext,
        })
        progressScope:setIndeterminate()

        rejectedResult = ScanRejected.collectRejectedFilenames({
            sourceFolderPath = sourceSelection.sourceFolderPath,
            recurseSource = sourceSelection.recurseSource,
            progressScope = progressScope,
        })

        if rejectedResult.canceled or rejectedResult.errorMessage then
            progressScope:done()
            return
        end

        local uniqueRejected = rejectedResult.uniqueRejectedCount or 0
        if uniqueRejected == 0 then
            -- Nothing to look for on the card; skip full media walk.
            externalResult = {
                matchedPaths = {},
                filesScanned = 0,
                directoriesScanned = 0,
                skippedExternalScan = true,
            }
            progressScope:done()
            return
        end

        externalResult = ScanExternal.collectMatches({
            externalRootPath = externalRootPath,
            rejectedFileNames = rejectedResult.rejectedFileNames,
            progressScope = progressScope,
        })

        progressScope:done()
    end)

    if not rejectedResult then
        return
    end

    if rejectedResult.canceled then
        LrDialogs.message("Scan canceled", "Stopped while scanning Lightroom folder.")
        return
    end

    if rejectedResult.errorMessage then
        LrDialogs.message("Source scan failed", rejectedResult.errorMessage, "critical")
        return
    end

    if not externalResult then
        return
    end

    if externalResult.canceled then
        LrDialogs.message("Scan canceled", "Stopped while scanning external media.")
        return
    end

    if externalResult.errorMessage then
        LrDialogs.message("External scan failed", externalResult.errorMessage, "critical")
        return
    end

    if externalResult.skippedExternalScan then
        LrDialogs.message(
            "No rejected photos in source folder",
            "There were no rejected (pick flag) images in the selected Lightroom folder, so the external volume was not scanned.",
            "info"
        )
        return
    end

    local confirmResult = UI.promptDeleteConfirmation({
        sourceFolderPath = sourceSelection.sourceFolderPath,
        recurseSource = sourceSelection.recurseSource,
        externalRootPath = externalRootPath,
        rejectedCount = rejectedResult.rejectedCount,
        matchedPaths = externalResult.matchedPaths,
    })

    if not confirmResult or not confirmResult.confirmed then
        if confirmResult and confirmResult.reason == "cancel" then
            LrDialogs.message("No files deleted", "You canceled before deletion.")
        end
        return
    end

    local deleteResultOrError

    LrFunctionContext.callWithContext("DeleteRejectedFromCard.Delete", function(deleteContext)
        local deleteProgress = LrDialogs.showModalProgressDialog({
            title = "Delete rejected from card",
            caption = "Deleting matched files...",
            cannotCancel = false,
            functionContext = deleteContext,
        })

        deleteResultOrError = MatchAndDelete.deleteMatches({
            matchedPaths = externalResult.matchedPaths,
            progressScope = deleteProgress,
        })

        deleteProgress:done()
    end)

    if deleteResultOrError then
        UI.showFinalReport(deleteResultOrError)
    end
end

LrTasks.startAsyncTask(function()
    LrFunctionContext.callWithContext("DeleteRejectedFromCard.Main", function(context)
        LrDialogs.attachErrorDialogToFunctionContext(context)
        runWorkflow()
    end)
end)
