class BlockProcessingData {
    string folderPath;
    Json::Value blocks;
    uint folderIndex;
    uint leafIndex;
    array<string> blocksWithDefaultRotation;
    array<string> folderPaths;
    dictionary processedBlocks;

    BlockProcessingData(const string &in path, const array<string> &in defaultRotationBlocks, const array<string> &in paths) {
        folderPath = path;
        blocks = Json::Array();
        folderIndex = 0;
        leafIndex = 0;
        blocksWithDefaultRotation = defaultRotationBlocks;
        folderPaths = paths;
        processedBlocks = dictionary();
    }
}

array<string> folderPaths = {
    "GameData/Stadium/GameCtnBlockInfo/GameCtnBlockInfoClassic",
    "GameData/Stadium/GameCtnBlockInfo/GameCtnBlockInfoClassic/Theme",
    "GameData/Stadium/GameCtnBlockInfo/GameCtnBlockInfoPillar",
    "GameData/Stadium/GameCtnBlockInfo/GameCtnBlockInfoPillar/Theme",
    "GameData/Stadium/Items",
    "GameData/Stadium/Items/Theme"
};

array<string> blocksWithDefaultRotation = {
    "DecoWallLoopEnd",
    "DecoWallArchSlope2Straight",
    "DecoWallArchSlope2End",
    "DecoWallArchSlope2UTop"
};

void Main() {
    BlockProcessingData data("", blocksWithDefaultRotation, folderPaths);

    log("Starting to process blocks.");
    startnew(Coro_ProcessBlocks, data);
}

void Coro_ProcessBlocks(ref@ dataRef) {
    BlockProcessingData@ data = cast<BlockProcessingData@>(dataRef);

    for (data.folderIndex = 0; data.folderIndex < data.folderPaths.Length; data.folderIndex++) {
        data.folderPath = data.folderPaths[data.folderIndex];
        log("Loading folder: " + data.folderPath);
        CSystemFidsFolder@ folder = Fids::GetGameFolder(data.folderPath);
        
        if (folder is null) {
            log("Failed to load folder at path: " + data.folderPath);
            continue;
        }

        log("Folder loaded successfully at path: " + data.folderPath);
        log("Folder name: " + folder.DirName);
        log("Number of leaves: " + folder.Leaves.Length);

        const uint batchSize = 40000;
        for (data.leafIndex = 0; data.leafIndex < folder.Leaves.Length; data.leafIndex++) {
            CSystemFidFile@ file = cast<CSystemFidFile@>(folder.Leaves[data.leafIndex]);
            
            if (file is null) {
                log("Encountered a null file pointer at index " + data.leafIndex);
                continue;
            }

            log("Processing block " + (data.leafIndex + 1) + " out of " + folder.Leaves.Length + ": " + file.FileName);
            ProcessBlock(file, data);

            if (data.leafIndex % batchSize == 0) {
                yield();
            }
        }
    }

    log("Finished processing blocks. Writing data to files.");
    
    _IO::File::WriteToFile(IO::FromStorageFolder("BlockData.json"), Json::Write(data.blocks));
    log("Block data written to " + IO::FromStorageFolder("BlockData.json"));
}

void ProcessBlock(CSystemFidFile@ file, BlockProcessingData@ data) {
    string fullBlockName = file.FileName;
    int endIndex = _Text::NthLastIndexOf(fullBlockName, ".", 2);
    if (endIndex < 0) {
        log("Failed to find block name for file: " + fullBlockName);
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
    return nat3(-1, -1, -1);
}
