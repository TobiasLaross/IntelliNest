#!/bin/zsh

# Navigate to the project root directory from Scripts
cd "${0:A:h}/.."

# Initialize metrics
typeset -A fileMetrics
typeset -A fileCounts
fileMetrics=(
    todoFiles ""
    fixFiles ""
    forceUnwrapFiles ""
    unownedFiles ""
    assignableVarFiles ""
)
fileCounts=(
    todoFiles 0
    fixFiles 0
    forceUnwrapFiles 0
    unownedFiles 0
    assignableVarFiles 0
)
maxIndentationLevel=0
maxIndentationFiles=()
totalLOC=0
swiftFileCount=0

# Helper function to add a file to the metric
add_file_to_metric() {
    local metric=$1
    local file=$2
    # Check if file is already in the list to prevent duplicates
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
        if [[ $line =~ "!" ]]; then
            add_file_to_metric forceUnwrapFiles "$file"
        fi
        if [[ $line =~ "unowned" ]]; then
            add_file_to_metric unownedFiles "$file"
        fi
        if [[ $line =~ "var " ]]; then
            add_file_to_metric assignableVarFiles "$file"
        fi

        # Calculate indentation level
        currentIndent=$(echo "$line" | grep -o '^\s*' | wc -m)
        if ((currentIndent > (maxIndentationLevel * 4))); then
            maxIndentationLevel=$((currentIndent / 4))
            maxIndentationFiles=("$file")
        elif ((currentIndent == (maxIndentationLevel * 4))); then
            maxIndentationFiles+=("$file")
        fi
    done < "$file"
done

# Calculate average LOC per Swift file
averageLOCPerFile=$((totalLOC / swiftFileCount))

# Function to print file names, max 3
print_files() {
    local files=("${(@s/ /)1}")
    local output=""
    for i in {1..3}; do
        [[ -n $files[i] ]] && output+="${files[i]}, "
    done
    echo "${output%, }" # Trim trailing comma and space
}

# Generate the Markdown table
tableContent="| Indicators                          | Now  | Desired | Triggering Files |
|-------------------------------------|------|---------|------------------|
| Total LOC                           | $totalLOC | N/A | N/A |
| Swift file count                    | $swiftFileCount | N/A | N/A |
| Average LOC per file                | $averageLOCPerFile | <100 | N/A |
| TODO comment count                  | $fileCounts[todoFiles] | 0 | $(print_files "${fileMetrics[todoFiles]}") |
| FIX comment count                   | $fileCounts[fixFiles] | 0 | $(print_files "${fileMetrics[fixFiles]}") |
| Optional force unwrap (!) count     | $fileCounts[forceUnwrapFiles] | 0 | $(print_files "${fileMetrics[forceUnwrapFiles]}") |
| unowned reference count             | $fileCounts[unownedFiles] | 0 | $(print_files "${fileMetrics[unownedFiles]}") |
| Max indentation level               | $maxIndentationLevel | <=5 | $(print_files "$maxIndentationFiles") |
| Assignable var declaration count    | $fileCounts[assignableVarFiles] | 0 | $(print_files "${fileMetrics[assignableVarFiles]}") |"

# Readme file location
readmeFile="README.md"

# Save the table content to a temporary file
tempFile=$(mktemp)
echo "$tableContent" > "$tempFile"

# Now replace the existing stats with the new table in README.md
{
    awk -v start="## Code statistics" -v end="^## " -v tempFile="$tempFile" '
        BEGIN { printit = 1 }
        $0 ~ start {
            print $0; 
            printit = 0; 
            while ((getline line < tempFile) > 0) {
                print line;
            }
            close(tempFile);
            next 
        }
        $0 ~ end && !printit { printit = 1 }
        printit { print }
    ' "$readmeFile"
} > "$readmeFile.tmp" && mv "$readmeFile.tmp" "$readmeFile"

# Remove the temporary file
rm "$tempFile"

echo "README.md has been updated with the latest code statistics."

