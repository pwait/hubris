#!/bin/bash
#
# GitHub User Email Export Script
#
# This script exports email addresses of GitHub users from:
# - Organization members
# - Repository contributors
# - Team members
#
# Requirements: GitHub CLI (gh) - https://cli.github.com/
# Usage: ./export-user-emails.sh [options]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FILE="github-users-emails.csv"
MODE=""
TARGET=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to check if gh is installed
check_gh_cli() {
    if ! command -v gh &> /dev/null; then
        print_error "GitHub CLI (gh) is not installed."
        echo ""
        echo "To install on macOS:"
        echo "  brew install gh"
        echo ""
        echo "Or download from: https://cli.github.com/"
        exit 1
    fi

    # Check if authenticated
    if ! gh auth status &> /dev/null; then
        print_error "Not authenticated with GitHub CLI."
        echo ""
        echo "Please run: gh auth login"
        exit 1
    fi

    print_success "GitHub CLI is installed and authenticated"
}

# Function to show usage
show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Export email addresses from GitHub users.

OPTIONS:
    -o, --org ORG          Export emails from organization members
    -r, --repo OWNER/REPO  Export emails from repository contributors
    -t, --team ORG/TEAM    Export emails from team members
    -f, --file FILE        Output file (default: github-users-emails.csv)
    -h, --help             Show this help message

EXAMPLES:
    # Export all members from an organization
    $0 --org mycompany

    # Export contributors from a repository
    $0 --repo mycompany/myrepo

    # Export team members
    $0 --team mycompany/engineering

    # Specify custom output file
    $0 --org mycompany --file contacts.csv

NOTES:
    - Requires GitHub CLI (gh) to be installed and authenticated
    - Email addresses depend on users' privacy settings
    - Some users may not have public email addresses
    - For organizations, requires appropriate permissions

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--org)
                MODE="org"
                TARGET="$2"
                shift 2
                ;;
            -r|--repo)
                MODE="repo"
                TARGET="$2"
                shift 2
                ;;
            -t|--team)
                MODE="team"
                TARGET="$2"
                shift 2
                ;;
            -f|--file)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Function to export organization members
export_org_members() {
    local org=$1
    print_info "Fetching members from organization: $org"

    # Create CSV header
    echo "username,name,email,profile_url" > "$OUTPUT_FILE"

    # Get organization members with their details
    gh api "orgs/$org/members" --paginate --jq '.[] | .login' | while read -r username; do
        print_info "Fetching details for: $username"

        # Get user details including email
        user_data=$(gh api "users/$username" --jq '{login, name, email, html_url}')

        login=$(echo "$user_data" | jq -r '.login')
        name=$(echo "$user_data" | jq -r '.name // "N/A"')
        email=$(echo "$user_data" | jq -r '.email // "N/A"')
        profile=$(echo "$user_data" | jq -r '.html_url')

        # Try to get email from user's events if not public
        if [ "$email" = "N/A" ] || [ "$email" = "null" ]; then
            email=$(gh api "users/$username/events/public" --jq '.[0].payload.commits[0].author.email // "N/A"' 2>/dev/null || echo "N/A")
        fi

        echo "\"$login\",\"$name\",\"$email\",\"$profile\"" >> "$OUTPUT_FILE"
    done
}

# Function to export repository contributors
export_repo_contributors() {
    local repo=$1
    print_info "Fetching contributors from repository: $repo"

    # Create CSV header
    echo "username,name,email,contributions,profile_url" > "$OUTPUT_FILE"

    # Get repository contributors
    gh api "repos/$repo/contributors" --paginate --jq '.[] | "\(.login),\(.contributions)"' | while IFS=, read -r username contributions; do
        print_info "Fetching details for: $username ($contributions contributions)"

        # Get user details
        user_data=$(gh api "users/$username" --jq '{login, name, email, html_url}')

        login=$(echo "$user_data" | jq -r '.login')
        name=$(echo "$user_data" | jq -r '.name // "N/A"')
        email=$(echo "$user_data" | jq -r '.email // "N/A"')
        profile=$(echo "$user_data" | jq -r '.html_url')

        # Try to get email from commits if not public
        if [ "$email" = "N/A" ] || [ "$email" = "null" ]; then
            email=$(gh api "repos/$repo/commits?author=$username" --jq '.[0].commit.author.email // "N/A"' 2>/dev/null || echo "N/A")
        fi

        echo "\"$login\",\"$name\",\"$email\",\"$contributions\",\"$profile\"" >> "$OUTPUT_FILE"
    done
}

# Function to export team members
export_team_members() {
    local org_team=$1
    local org=$(echo "$org_team" | cut -d'/' -f1)
    local team=$(echo "$org_team" | cut -d'/' -f2)

    print_info "Fetching members from team: $team in organization: $org"

    # Create CSV header
    echo "username,name,email,role,profile_url" > "$OUTPUT_FILE"

    # Get team slug
    team_slug=$(gh api "orgs/$org/teams" --jq ".[] | select(.name==\"$team\") | .slug")

    if [ -z "$team_slug" ]; then
        print_error "Team '$team' not found in organization '$org'"
        exit 1
    fi

    # Get team members
    gh api "orgs/$org/teams/$team_slug/members" --paginate --jq '.[] | .login' | while read -r username; do
        print_info "Fetching details for: $username"

        # Get user details
        user_data=$(gh api "users/$username" --jq '{login, name, email, html_url}')

        login=$(echo "$user_data" | jq -r '.login')
        name=$(echo "$user_data" | jq -r '.name // "N/A"')
        email=$(echo "$user_data" | jq -r '.email // "N/A"')
        profile=$(echo "$user_data" | jq -r '.html_url')

        # Get role in team
        role=$(gh api "orgs/$org/teams/$team_slug/memberships/$username" --jq '.role' 2>/dev/null || echo "member")

        # Try to get email from events if not public
        if [ "$email" = "N/A" ] || [ "$email" = "null" ]; then
            email=$(gh api "users/$username/events/public" --jq '.[0].payload.commits[0].author.email // "N/A"' 2>/dev/null || echo "N/A")
        fi

        echo "\"$login\",\"$name\",\"$email\",\"$role\",\"$profile\"" >> "$OUTPUT_FILE"
    done
}

# Main function
main() {
    echo ""
    print_info "GitHub User Email Export Script"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check if mode is set
    if [ -z "$MODE" ]; then
        print_error "No mode specified. Use --org, --repo, or --team"
        echo ""
        show_usage
        exit 1
    fi

    # Check GitHub CLI
    check_gh_cli

    echo ""

    # Export based on mode
    case $MODE in
        org)
            export_org_members "$TARGET"
            ;;
        repo)
            export_repo_contributors "$TARGET"
            ;;
        team)
            export_team_members "$TARGET"
            ;;
    esac

    echo ""
    print_success "Export completed!"
    print_info "Output saved to: $OUTPUT_FILE"

    # Count results
    total_users=$(($(wc -l < "$OUTPUT_FILE") - 1))
    users_with_email=$(grep -v "N/A" "$OUTPUT_FILE" | grep -v "username,name,email" | wc -l | tr -d ' ')

    echo ""
    print_info "Total users: $total_users"
    print_info "Users with email addresses: $users_with_email"

    if [ "$users_with_email" -lt "$total_users" ]; then
        echo ""
        print_warning "Some users don't have public email addresses."
        print_warning "Consider reaching out to them via GitHub directly."
    fi

    echo ""
    print_info "You can now use this CSV file with your email client or mail merge tool."
    echo ""
}

# Run main function
main "$@"
