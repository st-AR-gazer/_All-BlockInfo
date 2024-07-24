// Use "size" for extracting sizes, 
// Use "extract" for extracting blocks/items, 
// Use "none" for doing nothing
const string START_CONDITION = "extract"; 

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
    "DecoWallArchSlope2UTop",
    "DecoWallLoopOutStart"
};

void Main() {
    string outputDirectory = START_CONDITION == "size" ? "size" : "extract";
    BlockProcessingData data("", blocksWithDefaultRotation, folderPaths, outputDirectory);

    log("Starting to process blocks.", LogLevel::Info, 27, "Main");
    if (START_CONDITION == "size") {
        startnew(Coro_ProcessBlockSizes, data);
    } else if (START_CONDITION == "extract") {
        startnew(Coro_ExtractBlocksAndItems, data);
    } else if (START_CONDITION == "none") {
        log("No action specified. Exiting script.", LogLevel::Info, 33, "Main");
    }
}

class BlockProcessingData {
    string folderPath;
    Json::Value blocks;
    uint folderIndex;
    uint leafIndex;
    array<string> blocksWithDefaultRotation;
    array<string> folderPaths;
    dictionary processedBlocks;
    string outputDirectory;

    BlockProcessingData(const string &in path, const array<string> &in defaultRotationBlocks, const array<string> &in paths, const string &in outputDir) {
        folderPath = path;
        blocks = Json::Array();
        folderIndex = 0;
        leafIndex = 0;
        blocksWithDefaultRotation = defaultRotationBlocks;
        folderPaths = paths;
        processedBlocks = dictionary();
        outputDirectory = outputDir;
    }
}
