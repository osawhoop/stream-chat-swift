#!/bin/bash

TARGET=$1

# Move to project root directory
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$scriptDir/../"


if [[ "$TARGET" = "StreamChat" ]];then
    TARGET_DIRECTORY="Sources/StreamChat"
elif [[ "$TARGET" = "StreamChatUI" ]]; then
    TARGET_DIRECTORY="Sources/StreamChatUI"
else
    echo "Please specify target to generate docs for (StreamChat or StreamChatUI)"
    exit 1
fi

IGNORED_PATHS='Resources\|__Snapshots__\|Tests\|Generated'

# As of May 2021, swift-doc doesn't support directories, so we find all the subdirectories instead
find "$TARGET_DIRECTORY" -type d -print | grep -v -e $IGNORED_PATHS > /tmp/StreamChat_folder_directories.txt

# Let's run the documentation inside all subdirectories in the target and directory so we can mirror the directories structure
while read directory; do
  swift doc generate $directory -n StreamChatUI  -o Documentation/$directory 
done < /tmp/StreamChat_folder_directories.txt

#cleanup the duplicate files by comparing what is not in the Sources directory.
bash Scripts/deleteDuplicates.sh "Documentation/$TARGET_DIRECTORY" "$TARGET_DIRECTORY"

rm -rf Scripts/StreamChat_folder_directories.txt

echo "Documentation for $TARGET generated successfully. Please do check Documentations folder "
