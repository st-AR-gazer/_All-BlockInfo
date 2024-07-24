void Coro_ProcessBlockSizes(ref@ dataRef) {
    BlockProcessingData@ data = cast<BlockProcessingData@>(dataRef);

    for (data.folderIndex = 0; data.folderIndex < data.folderPaths.Length; data.folderIndex++) {
        data.folderPath = data.folderPaths[data.folderIndex];
        log("Loading folder: " + data.folderPath, LogLevel::Info, 6, "Coro_ProcessBlockSizes");
        CSystemFidsFolder@ folder = Fids::GetGameFolder(data.folderPath);
        
        if (folder is null) {
            log("Failed to load folder at path: " + data.folderPath, LogLevel::Info, 10, "Coro_ProcessBlockSizes");
            continue;
        }

        log("Folder loaded successfully at path: " + data.folderPath, LogLevel::Info, 14, "Coro_ProcessBlockSizes");

        const uint batchSize = 40000;
        for (data.leafIndex = 0; data.leafIndex < folder.Leaves.Length; data.leafIndex++) {
            CSystemFidFile@ file = cast<CSystemFidFile@>(folder.Leaves[data.leafIndex]);
            
            if (file is null) {
                log("Encountered a null file pointer at index " + data.leafIndex, LogLevel::Info, 21, "Coro_ProcessBlockSizes");
                continue;
            }

            log("Processing block " + (data.leafIndex + 1) + " out of " + folder.Leaves.Length + ": " + file.FileName, LogLevel::Info, 25, "Coro_ProcessBlockSizes");
            ProcessBlockSize(file, data);

            if (data.leafIndex % batchSize == 0) {
                yield();
            }
        }
    }

    log("Finished processing block sizes. Writing data to files.", LogLevel::Info, 34, "Coro_ProcessBlockSizes");
    WriteJsonToFile(data.blocks, "BlockData.json");
}

void ProcessBlockSize(CSystemFidFile@ file, BlockProcessingData@ data) {
    string fullBlockName = file.FileName;
    int endIndex = _Text::NthLastIndexOf(fullBlockName, ".", 2);
    if (endIndex < 0) {
        log("Failed to find block name for file: " + fullBlockName, LogLevel::Info, 42, "ProcessBlockSize");
        return;
    }
    string blockName = fullBlockName.SubStr(0, endIndex);

    if (data.processedBlocks.Exists(blockName)) {
        return;
    }
    data.processedBlocks.Set(blockName, true);

    nat3 size = nat3(-1, -1, -1);
    if (!file.FileName.StartsWith("Items")) {
        size = GetBlockSize(file);
    }

    Json::Value blockInfo = Json::Object();
    blockInfo["Name"] = blockName;
    blockInfo["Width"] = size.x;
    blockInfo["Length"] = size.z;
    blockInfo["Height"] = size.y;
    blockInfo["Theme"] = (data.folderIndex % 2 == 1);

    if (data.folderIndex < 2) {
        blockInfo["type"] = "Block";
    } else if (data.folderIndex < 4) {
        blockInfo["type"] = "Pillar";
    } else {
        blockInfo["type"] = "Item";
    }

    if (data.blocksWithDefaultRotation.Find(blockName) >= 0) {
        blockInfo["DefaultRotation"] = true;
    } else {
        blockInfo["DefaultRotation"] = false;
    }

    data.blocks.Add(blockInfo);
}

nat3 GetBlockSize(CSystemFidFile@ file) {
    CMwNod@ nod = Fids::Preload(file);
    CGameCtnBlockInfoClassic@ blockInfo = cast<CGameCtnBlockInfoClassic@>(nod);
    if (blockInfo !is null && blockInfo.VariantBaseGround !is null) {
        return blockInfo.VariantBaseGround.Size;
    }
    return nat3(0, 0, 0);
}

void WriteJsonToFile(const Json::Value &in data, const string &in filename) {
    _IO::File::WriteToFile(IO::FromStorageFolder(filename), Json::Write(data));
    log("Block data written to " + IO::FromStorageFolder(filename), LogLevel::Info, 92, "WriteJsonToFile");
}
