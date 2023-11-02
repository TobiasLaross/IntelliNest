#!/bin/zsh

# Navigate to the project root directory from Scripts
cd "${0:A:h}/.."

# Initialize metrics
typeset -A fileMetrics
typeset -A fileCounts
fileMetrics=(
    todoFiles ""
    fixFiles ""
    unownedFiles ""
)
fileCounts=(
    todoFiles 0
    fixFiles 0
    unownedFiles 0
)
totalLOC=0
swiftFileCount=0

# Git metrics
commitCount=$(git rev-list --count HEAD)
totalDeletedLines=$(git log --pretty=tformat: --numstat | awk '{deletions+=$2} END {print deletions}')
totalAddedLines=$(git log --pretty=tformat: --numstat | awk '{additions+=$1} END {print additions}')

# Helper function to add a file to the metric
add_file_to_metric() {
    local metric=$1
    local file=$2
    if [[ ${fileMetrics[$metric]} != *"$file"* ]]; then
        if (( fileCounts[$metric] < 3 )); then
            fileMetrics[$metric]+="$file "
            ((fileCounts[$metric]++))
        fi
    fi
}

# Process each Swift file
for file in **/*.swift(.); do
    swiftFileCount=$((swiftFileCount + 1))
    loc=$(wc -l < "$file")
    totalLOC=$((totalLOC + loc))

    while IFS= read -r line; do
        if [[ $line =~ "// TODO:" ]]; then
            add_file_to_metric todoFiles "$file"
        fi
        if [[ $line =~ "// FIX:" ]]; then
            add_file_to_metric fixFiles "$file"
        fi
        if [[ $line =~ "unowned" ]]; then
            add_file_to_metric unownedFiles "$file"
        fi
    done < "$file"
done

# Calculate average LOC per Swift file
averageLOCPerFile=$((totalLOC / swiftFileCount))

# Generate the Markdown table
tableContent="| Indicators                          | Now  | Desired |
|-------------------------------------|------|---------|
| Total LOC                           | $totalLOC | N/A |
| Swift file count                    | $swiftFileCount | N/A |
| Average LOC per file                | $averageLOCPerFile | <100 |
| TODO comment count                  | $fileCounts[todoFiles] | 0 |
| FIX comment count                   | $fileCounts[fixFiles] | 0 |
| unowned reference count             | $fileCounts[unownedFiles] | 0 |
| Commit count in main                | $commitCount | N/A |
| Total deleted lines                 | $totalDeletedLines | N/A |
| Total added lines                   | $totalAddedLines | N/A |"

# Save the table content to a temporary file
tableFile=$(mktemp)
echo "$tableContent" > "$tableFile"

# Readme file location
readmeFile="README.md"

# Define the section start and end markers
startMarker="## Code statistics"
endMarker="## " # The next heading

# Insert a unique placeholder for the new content
placeholder="<!-- NEW_STATS_CONTENT -->"

# Use awk to place the placeholder in the README.md
awk -v start="$startMarker" -v end="$endMarker" -v placeholder="$placeholder" '
  $0 ~ start {print; skip=1; print placeholder; next}
  $0 ~ end && skip {skip=0}
  !skip {print}
' "$readmeFile" > "$readmeFile.tmp"

# Now, use sed to replace the placeholder with the actual table content
sed -i '' "/$placeholder/r $tableFile" "$readmeFile.tmp"
sed -i '' "/$placeholder/d" "$readmeFile.tmp"

# Move the temporary file to the README.md
mv "$readmeFile.tmp" "$readmeFile"

# Clean up the temporary table content file
rm "$tableFile"

echo "README.md has been updated with the latest code statistics."

