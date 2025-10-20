# Set start and end dates
START_DATE="2025-10-18"
END_DATE="2025-11-04"

commit_messages=(
    "Initial commit"
    "Setup architecture and framework"
    "Refactor 2D floor plan with SpriteKit for accurate 3D to 2D projection Add rotation field to RoomStructureData."
    "Fix 2D floor plan rendering with SpriteKit-based projection"
    "2D plan improvements"
    "icon"
    "Fix screen timeout and dded units"
    "Updated version"
    "working on 2D implification"
    "updated 2D plan"
    "updated 2D plan"
    "Thin walls and added windows"
    "2D floor plan Ui improvements to match the provided reference and update controls ui for liquid glass support"
    "Updated version and encryption"
    "Added 2D floor plan share feature (png)"
    "#740: Freely moving the image around to look at different areas of the floor plan"
)


# Loop through each day from START_DATE to END_DATE
while [ "$(date -d "$START_DATE" +%Y-%m-%d)" != "$(date -d "$END_DATE + 1 day" +%Y-%m-%d)" ]; do
    # Decide randomly if this day should have commits (3-4 active days per week)
    if [ $((RANDOM % 7)) -lt 4 ]; then  # 4/7 chance of committing
        # Generate a random number of commits for the day (1 to 3 commits)
        NUM_COMMITS=$((RANDOM % 3 + 1))

        for ((i = 1; i <= NUM_COMMITS; i++)); do
            # Generate a random time during the day
            HOUR=$((RANDOM % 24))
            MINUTE=$((RANDOM % 60))
            SECOND=$((RANDOM % 60))

            # Set the commit date and time
            COMMIT_DATE="$START_DATE $HOUR:$MINUTE:$SECOND"
            commit_message=${commit_messages[$RANDOM % ${#commit_messages[@]}]}

            # Create a commit
            export GIT_AUTHOR_DATE="$COMMIT_DATE"
            export GIT_COMMITTER_DATE="$COMMIT_DATE"
            echo "$commit_message" > commit.txt
            git add commit.txt -f
            git commit -m "$commit_message"
        done
    fi

    # Increment the date by 1 day
    START_DATE=$(date -I -d "$START_DATE + 1 day")
done