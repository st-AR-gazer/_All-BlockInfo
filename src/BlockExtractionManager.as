void Coro_ExtractBlocksAndItems(ref@ dataRef) {
    BlockProcessingData@ data = cast<BlockProcessingData@>(dataRef);

    for (data.folderIndex = 0; data.folderIndex < data.folderPaths.Length; data.folderIndex++) {
        data.folderPath = data.folderPaths[data.folderIndex];
        log("Loading folder: " + data.folderPath, LogLevel::Info, 6, "Coro_ExtractBlocksAndItems");
        CSystemFidsFolder@ folder = Fids::GetGameFolder(data.folderPath);
        
        if (folder is null) {
            log("Failed to load folder at path: " + data.folderPath, LogLevel::Info, 10, "Coro_ExtractBlocksAndItems");
            continue;
        }

        log("Folder loaded successfully at path: " + data.folderPath, LogLevel::Info, 14, "Coro_ExtractBlocksAndItems");

        const uint batchSize = 40000;
        for (data.leafIndex = 0; data.leafIndex < folder.Leaves.Length; data.leafIndex++) {
            CSystemFidFile@ file = cast<CSystemFidFile@>(folder.Leaves[data.leafIndex]);
            
            if (file is null) {
                log("Encountered a null file pointer at index " + data.leafIndex, LogLevel::Info, 21, "Coro_ExtractBlocksAndItems");
                continue;
            }

            log("Extracting file " + (data.leafIndex + 1) + " out of " + folder.Leaves.Length + ": " + file.FileName, LogLevel::Info, 25, "Coro_ExtractBlocksAndItems");
            ExtractBlockOrItem(file, data);

            if (data.leafIndex % batchSize == 0) {
                yield();
            }
        }
    }

    log("Finished extracting blocks and items. Writing data to files.", LogLevel::Info, 34, "Coro_ExtractBlocksAndItems");
    WriteJsonToFile(data.blocks, IO::FromStorageFolder(data.outputDirectory + "/BlockData.json"));
}

void ExtractBlockOrItem(CSystemFidFile@ file, BlockProcessingData@ data) {
    string fullBlockName = file.FileName;
    int endIndex = _Text::NthLastIndexOf(fullBlockName, ".", 2);
    if (endIndex < 0) {
        log("Failed to find block name for file: " + fullBlockName, LogLevel::Info, 42, "ExtractBlockOrItem");
        return;
    }
    string blockName = fullBlockName.SubStr(0, endIndex);

    if (data.processedBlocks.Exists(blockName)) {
        return;
    }
    data.processedBlocks.Set(blockName, true);

    if (!file.FileName.StartsWith("Items")) {
        ExtractAndMoveFile(file, blockName + ".Block.Gbx", data.outputDirectory);
    } else {
        ExtractAndMoveFile(file, blockName + ".Item.Gbx", data.outputDirectory);
    }
}

void ExtractAndMoveFile(CSystemFidFile@ file, const string &in filename, const string &in outputDir) {
    if (Fids::Extract(file)) {
        string extractedFilePath = IO::FromAppFolder("GameData/" + file.FileName);
        string destinationPath = IO::FromStorageFolder(outputDir + "/" + filename);
        if (IO::FileExists(extractedFilePath)) {
            _IO::File::MoveFile(extractedFilePath, destinationPath);
            log("Moved " + extractedFilePath + " to " + destinationPath, LogLevel::Info, 65, "ExtractAndMoveFile");
        } else {
            log("File extraction failed: " + extractedFilePath + " does not exist.", LogLevel::Error, 67, "ExtractAndMoveFile");
        }
    } else {
        log("Failed to extract file: " + file.FileName, LogLevel::Error, 70, "ExtractAndMoveFile");
    }
}

void WriteJsonToFile(const Json::Value &in data, const string &in filename) {
    _IO::File::WriteToFile(filename, Json::Write(data));
    log("Block data written to " + filename, LogLevel::Info, 76, "WriteJsonToFile");
}
