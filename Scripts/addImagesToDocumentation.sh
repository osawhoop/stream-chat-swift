#!/bin/bash

# Move to project root directory
scriptDir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$scriptDir/../"

PATH_TO_SNAPSHOTS="Tests/StreamChatUITests/UISDKdocumentation/__Snapshots__"

for UI_SNAPSHOT in ${PATH_TO_SNAPSHOTS}/*;do
    STRIPPED_PATH=`basename $UI_SNAPSHOT`
    COMPONENT_NAME=${STRIPPED_PATH%_*_*}
    
    DOCUMENTATION_FILE=`find Documentation/Sources/StreamChatUI -name "_$COMPONENT_NAME.md"`
    # Let's use just light variation of the screenshot, we can support dark mode later.
    FINAL_SNAPSHOT=`ls $UI_SNAPSHOT | grep light`
    tail -1 "$DOCUMENTATION_FILE" | grep "$FINAL_SNAPSHOT"
    if [ $? -eq 0 ];then
        echo "There is already line containing the snapshot for $COMPONENT_NAME, skipping adding of documentation."
        continue
    fi
    
    echo "Adding snapshot of $COMPONENT_NAME to documentation..."
    echo -e "\n![$COMPONENT_NAME](/$UI_SNAPSHOT/$FINAL_SNAPSHOT)" >> $DOCUMENTATION_FILE
done
