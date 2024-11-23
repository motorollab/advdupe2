local invalidCharacters = { "\"", ":" }
function AdvDupe2.SanitizeFilename( filename )
    for i = 1, #invalidCharacters do
        filename = string.gsub( filename, invalidCharacters[i], "_" )
    end
    filename = string.gsub( filename, "%s+", " " )

    return filename
end

function AdvDupe2.ReceiveFile( data )
    local autoSave = data.autosave == 1
    data = data.data

    AdvDupe2.RemoveProgressBar()
    if not data then
        AdvDupe2.Notify( "File was not saved!", NOTIFY_ERROR, 5 )
        return
    end
    local path
    if autoSave then
        if (LocalPlayer():GetInfo( "advdupe2_auto_save_overwrite" ) ~= "0") then
            path = AdvDupe2.GetFilename( AdvDupe2.AutoSavePath, true )
        else
            path = AdvDupe2.GetFilename( AdvDupe2.AutoSavePath )
        end
    else
        path = AdvDupe2.GetFilename( AdvDupe2.SavePath )
    end

    path = AdvDupe2.SanitizeFilename( path )
    local dupefile = file.Open( path, "wb", "DATA" )
    if not dupefile then
        AdvDupe2.Notify( "File was not saved!", NOTIFY_ERROR, 5 )
        return
    end
    dupefile:Write( data )
    dupefile:Close()

    local errored = false
    if (LocalPlayer():GetInfo( "advdupe2_debug_openfile" ) == "1") then
        if (not file.Exists( path, "DATA" )) then
            AdvDupe2.Notify( "File does not exist", NOTIFY_ERROR )
            return
        end

        local readFile = file.Open( path, "rb", "DATA" )
        if not readFile then
            AdvDupe2.Notify( "File could not be read", NOTIFY_ERROR )
            return
        end
        local readData = readFile:Read( readFile:Size() )
        readFile:Close()
        local success, dupe = AdvDupe2.Decode( readData )
        if (success) then
            AdvDupe2.Notify( "DEBUG CHECK: File successfully opens. No EOF errors." )
        else
            AdvDupe2.Notify( "DEBUG CHECK: " .. dupe, NOTIFY_ERROR )
            errored = true
        end
    end

    local filename = string.StripExtension( string.GetFileFromFilename( path ) )
    if autoSave then
        if (IsValid( AdvDupe2.FileBrowser.AutoSaveNode )) then
            local add = true
            for i = 1, #AdvDupe2.FileBrowser.AutoSaveNode.Files do
                if (filename == AdvDupe2.FileBrowser.AutoSaveNode.Files[i].Label:GetText()) then
                    add = false
                    break
                end
            end
            if (add) then
                AdvDupe2.FileBrowser.AutoSaveNode:AddFile( filename )
                AdvDupe2.FileBrowser.Browser.pnlCanvas:Sort( AdvDupe2.FileBrowser.AutoSaveNode )
            end
        end
    else
        AdvDupe2.FileBrowser.Browser.pnlCanvas.ActionNode:AddFile( filename )
        AdvDupe2.FileBrowser.Browser.pnlCanvas:Sort( AdvDupe2.FileBrowser.Browser.pnlCanvas.ActionNode )
    end
    if (not errored) then
        AdvDupe2.Notify( "File successfully saved!", NOTIFY_GENERIC, 5 )
    end
end
express.Receive( "AdvDupe2_ReceiveFile", AdvDupe2.ReceiveFile )

AdvDupe2.Uploading = false
function AdvDupe2.UploadFile( ReadPath, ReadArea )
    if AdvDupe2.Uploading then
        return AdvDupe2.Notify( "Already opening file, please wait.", NOTIFY_ERROR )
    end

    if ReadArea == 0 then
        ReadPath = AdvDupe2.DataFolder .. "/" .. ReadPath .. ".txt"
    elseif ReadArea == 1 then
        ReadPath = AdvDupe2.DataFolder .. "/-Public-/" .. ReadPath .. ".txt"
    else
        ReadPath = "adv_duplicator/" .. ReadPath .. ".txt"
    end

    if not file.Exists( ReadPath, "DATA" ) then
        return AdvDupe2.Notify( "File does not exist", NOTIFY_ERROR )
    end

    local read = file.Read( ReadPath )
    if not read then
        return AdvDupe2.Notify( "File could not be read", NOTIFY_ERROR )
    end

    local name = string.Explode( "/", ReadPath )
    name = name[#name]
    name = string.sub( name, 1, #name - 4 )

    AdvDupe2.DecodeAsync( read, function( success, dupe, info, moreinfo )
        if not success then
            return AdvDupe2.Notify( "File could not be decoded. (" .. dupe .. ") Upload Canceled.", NOTIFY_ERROR )
        end

        timer.Create( "bulk_adv2_timeout", 5, 1, function()
            AdvDupe2.File = nil
            AdvDupe2.Uploading = false
            AdvDupe2.RemoveProgressBar()

            local message = "Превышено время ожидания. Попробуйте еще раз."
            AdvDupe2.Notify( message, NOTIFY_ERROR )
        end )

        express.Send( "AdvDupe2_ReceiveFile", { name = name, read = read }, function()
            AdvDupe2.File = nil
            AdvDupe2.Uploading = false
            AdvDupe2.RemoveProgressBar()
            AdvDupe2.LoadGhosts( dupe, info, moreinfo, name )

            timer.Remove( "bulk_adv2_timeout" )
        end )

        AdvDupe2.Uploading = true
        AdvDupe2.InitProgressBar( "Sending:" )
    end )
end
