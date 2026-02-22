#!/bin/bash

# Configuration
REPO="setya-rgb/oh-my-termux"
BRANCH="main" # Change to your default branch if different

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if gh CLI is installed and authenticated
check_gh_cli() {
  if ! command -v gh &>/dev/null; then
    print_error "GitHub CLI (gh) is not installed."
    echo "Please install it first:"
    echo "  - On Termux: pkg install gh"
    echo "  - Then authenticate: gh auth login"
    exit 1
  fi

  if ! gh auth status &>/dev/null; then
    print_error "Not authenticated with GitHub."
    echo "Please run: gh auth login"
    exit 1
  fi
}

# Check if repository exists and is accessible
check_repository() {
  print_status "Checking repository access: $REPO"
  if gh repo view "$REPO" &>/dev/null; then
    print_success "Repository found and accessible"
  else
    print_error "Repository not found or not accessible"
    echo "Please check:"
    echo "  - Repository name: $REPO"
    echo "  - Your permissions"
    exit 1
  fi
}

# Get current branch if not specified
get_default_branch() {
  local default_branch
  default_branch=$(gh api "repos/$REPO" --jq '.default_branch' 2>/dev/null)
  if [ -n "$default_branch" ]; then
    BRANCH="$default_branch"
    print_status "Using default branch: $BRANCH"
  fi
}

# Function to encode file to base64
encode_file() {
  base64 -w 0 "$1" 2>/dev/null || base64 "$1" 2>/dev/null
}

# Function to check if file exists in repository
file_exists_in_repo() {
  local file=$1
  gh api "repos/$REPO/contents/$file?ref=$BRANCH" --silent 2>/dev/null
  return $?
}

# Function to get file SHA if it exists
get_file_sha() {
  local file=$1
  gh api "repos/$REPO/contents/$file?ref=$BRANCH" --jq '.sha' 2>/dev/null
}

# Function to upload a single file
upload_file() {
  local file=$1
  local commit_message=$2
  local sha=""

  print_status "Processing: $file"

  # Check if file exists locally
  if [ ! -f "$file" ]; then
    print_error "File not found: $file"
    return 1
  fi

  # Check file size (GitHub limit is 100MB)
  local file_size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
  if [ "$file_size" -gt 100000000 ]; then
    print_error "File too large (>100MB): $file"
    return 1
  fi

  # Check if file exists in repo and get SHA
  if file_exists_in_repo "$file"; then
    sha=$(get_file_sha "$file")
    print_warning "File exists in repository. Will update."
  else
    print_status "New file. Will create."
  fi

  # Encode file content
  local content
  content=$(encode_file "$file")
  if [ -z "$content" ]; then
    print_error "Failed to encode file: $file"
    return 1
  fi

  # Prepare JSON payload
  local json_payload
  if [ -n "$sha" ]; then
    # Update existing file
    json_payload=$(jq -n \
      --arg msg "$commit_message" \
      --arg content "$content" \
      --arg sha "$sha" \
      --arg branch "$BRANCH" \
      '{message: $msg, content: $content, sha: $sha, branch: $branch}')
  else
    # Create new file
    json_payload=$(jq -n \
      --arg msg "$commit_message" \
      --arg content "$content" \
      --arg branch "$BRANCH" \
      '{message: $msg, content: $content, branch: $branch}')
  fi

  # Upload file
  local response
  response=$(gh api "repos/$REPO/contents/$file" \
    -X PUT \
    --input <(echo "$json_payload") \
    2>&1)

  if [ $? -eq 0 ]; then
    print_success "Uploaded: $file"
    return 0
  else
    print_error "Failed to upload: $file"
    echo "$response"
    return 1
  fi
}

# Function to upload all files in directory
upload_all_files() {
  local commit_message=$1
  local success_count=0
  local fail_count=0
  local skipped_count=0

  print_status "Starting upload of all files in current directory to $REPO:$BRANCH"
  echo "=================================================="

  # Get list of files (excluding hidden files and directories)
  local files=()
  while IFS= read -r -d '' file; do
    # Skip directories, hidden files, and common exclude patterns
    if [ -f "$file" ] && [[ ! "$file" =~ ^\. ]]; then
      # Skip common files that shouldn't be uploaded
      case "$(basename "$file")" in
      .gitignore | .gitmodules | *.log | *.tmp | *.swp | *.bak)
        print_warning "Skipping: $file (excluded pattern)"
        ((skipped_count++))
        ;;
      *)
        files+=("$file")
        ;;
      esac
    fi
  done < <(find . -maxdepth 1 -type f -print0)

  print_status "Found ${#files[@]} files to upload"
  echo "=================================================="

  # Upload each file
  for file in "${files[@]}"; do
    # Remove './' prefix if present
    file="${file#./}"

    if upload_file "$file" "$commit_message"; then
      ((success_count++))
    else
      ((fail_count++))
    fi

    echo "--------------------------------------------------"
  done

  # Summary
  echo "=================================================="
  print_status "Upload complete!"
  echo "  Successful: $success_count"
  echo "  Failed: $fail_count"
  echo "  Skipped: $skipped_count"
  echo "=================================================="

  # Show uploaded files on GitHub
  if [ $success_count -gt 0 ]; then
    print_status "View files at: https://github.com/$REPO/tree/$BRANCH"
  fi
}

# Function to upload with specific file patterns
upload_pattern() {
  local pattern=$1
  local commit_message=$2

  print_status "Uploading files matching pattern: $pattern"

  local success_count=0
  local fail_count=0

  for file in $pattern; do
    if [ -f "$file" ]; then
      if upload_file "$file" "$commit_message"; then
        ((success_count++))
      else
        ((fail_count++))
      fi
    fi
  done

  print_status "Pattern upload complete: $success_count successful, $fail_count failed"
}

# Function to create or update multiple files with single commit
upload_batch() {
  local files=("${@:1:$#-1}")
  local commit_message="${@: -1}"

  print_status "Batch uploading ${#files[@]} files"

  # This is more complex as GitHub API doesn't support batch updates directly
  # For now, we'll upload them sequentially
  for file in "${files[@]}"; do
    if [ -f "$file" ]; then
      upload_file "$file" "$commit_message"
    fi
  done
}

# Function to show menu
show_menu() {
  echo ""
  echo "=== Upload Options ==="
  echo "1) Upload all files in current directory"
  echo "2) Upload specific files (enter patterns)"
  echo "3) Upload only shell scripts (*.sh)"
  echo "4) Upload only documentation (*.md)"
  echo "5) Upload only configuration files (*.conf, *.json, *.yml)"
  echo "6) Custom upload (specify files)"
  echo "7) Check what would be uploaded (dry run)"
  echo "8) Exit"
  echo ""
  echo -n "Choose an option (1-8): "
}

# Function for dry run
dry_run() {
  print_status "Dry run - files that would be uploaded:"
  echo "=================================================="

  local count=0
  while IFS= read -r -d '' file; do
    if [ -f "$file" ] && [[ ! "$file" =~ ^\. ]]; then
      file="${file#./}"
      if file_exists_in_repo "$file" 2>/dev/null; then
        echo "📝 Update: $file"
      else
        echo "🆕 New:    $file"
      fi
      ((count++))
    fi
  done < <(find . -maxdepth 1 -type f -print0)

  echo "=================================================="
  echo "Total: $count files"
}

# Main execution
main() {
  echo "=== GitHub Upload Tool ==="
  echo "Repository: $REPO"
  echo "Directory: $(pwd)"
  echo ""

  # Check prerequisites
  check_gh_cli
  check_repository
  get_default_branch

  # Interactive menu
  while true; do
    show_menu
    read -r choice

    case $choice in
    1)
      echo ""
      echo -n "Enter commit message (default: 'Update files'): "
      read -r commit_msg
      commit_msg=${commit_msg:-"Update files"}
      upload_all_files "$commit_msg"
      ;;
    2)
      echo ""
      echo -n "Enter file pattern (e.g., *.sh *.md): "
      read -r pattern
      echo -n "Enter commit message: "
      read -r commit_msg
      upload_pattern "$pattern" "$commit_msg"
      ;;
    3)
      upload_pattern "*.sh" "Update shell scripts"
      ;;
    4)
      upload_pattern "*.md" "Update documentation"
      ;;
    5)
      upload_pattern "*.conf *.json *.yml *.yaml" "Update configuration files"
      ;;
    6)
      echo ""
      echo "Enter filenames (space-separated): "
      read -r -a files
      echo -n "Enter commit message: "
      read -r commit_msg
      upload_batch "${files[@]}" "$commit_msg"
      ;;
    7)
      dry_run
      ;;
    8)
      print_status "Exiting..."
      exit 0
      ;;
    *)
      print_error "Invalid option"
      ;;
    esac

    echo ""
    echo -n "Press Enter to continue..."
    read
  done
}

# Run main function
main
