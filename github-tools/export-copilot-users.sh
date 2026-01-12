#!/bin/bash
#
# GitHub Copilot User Email Export Script
#
# This script exports email addresses of users with GitHub Copilot seats
# in your organization.
#
# Requirements: GitHub CLI (gh) - https://cli.github.com/
# Usage: ./export-copilot-users.sh --org YOUR_ORG [options]

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
OUTPUT_FILE="copilot-users-emails.csv"
ORG=""
SEAT_STATUS="all"  # all, active, or pending

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
Usage: $0 --org ORG [OPTIONS]

Export email addresses from GitHub Copilot users in your organization.

REQUIRED:
    -o, --org ORG          Organization name

OPTIONS:
    -s, --status STATUS    Filter by seat status: all, active, pending (default: all)
    -f, --file FILE        Output file (default: copilot-users-emails.csv)
    -h, --help             Show this help message

EXAMPLES:
    # Export all Copilot users from organization
    $0 --org mycompany

    # Export only active Copilot users
    $0 --org mycompany --status active

    # Export to custom file
    $0 --org mycompany --file copilot-contacts.csv

NOTES:
    - Requires GitHub CLI (gh) to be installed and authenticated
    - Requires admin access to the organization
    - Email addresses depend on users' privacy settings
    - Some users may not have public email addresses

PERMISSIONS:
    You need to be an organization admin to access Copilot seat information.
    The GitHub CLI token must have the 'manage_billing:copilot' scope.

EOF
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -o|--org)
                ORG="$2"
                shift 2
                ;;
            -s|--status)
                SEAT_STATUS="$2"
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

# Function to export Copilot users
export_copilot_users() {
    local org=$1
    print_info "Fetching GitHub Copilot seat assignments for: $org"
    echo ""

    # Create CSV header
    echo "username,name,email,seat_created,last_activity,status,profile_url" > "$OUTPUT_FILE"

    # Fetch Copilot seat assignments
    # Note: This requires the manage_billing:copilot scope
    local api_response
    if ! api_response=$(gh api "/orgs/$org/copilot/billing/seats" --paginate 2>&1); then
        print_error "Failed to fetch Copilot seats."
        echo ""
        if echo "$api_response" | grep -q "404"; then
            print_error "Organization not found or no Copilot subscription."
        elif echo "$api_response" | grep -q "403"; then
            print_error "Permission denied. You need admin access to the organization."
            print_info "Make sure you're authenticated with the right account:"
            echo "  gh auth login"
        fi
        exit 1
    fi

    # Parse and process each seat
    echo "$api_response" | jq -c '.seats[]? // empty' | while read -r seat; do
        local assignee_type=$(echo "$seat" | jq -r '.assignee.type')

        # Only process User type (not Teams or Organizations)
        if [ "$assignee_type" != "User" ]; then
            continue
        fi

        local username=$(echo "$seat" | jq -r '.assignee.login')
        local created_at=$(echo "$seat" | jq -r '.created_at')
        local last_activity=$(echo "$seat" | jq -r '.last_activity_at // "Never"')
        local pending=$(echo "$seat" | jq -r '.pending_cancellation_date // empty')

        # Determine status
        local status="active"
        if [ -n "$pending" ]; then
            status="pending_cancellation"
        fi

        # Filter by status if specified
        if [ "$SEAT_STATUS" != "all" ]; then
            if [ "$SEAT_STATUS" = "active" ] && [ "$status" != "active" ]; then
                continue
            elif [ "$SEAT_STATUS" = "pending" ] && [ "$status" != "pending_cancellation" ]; then
                continue
            fi
        fi

        print_info "Processing: $username (status: $status)"

        # Get user details including email
        local user_data=$(gh api "users/$username" --jq '{login, name, email, html_url}')

        local login=$(echo "$user_data" | jq -r '.login')
        local name=$(echo "$user_data" | jq -r '.name // "N/A"')
        local email=$(echo "$user_data" | jq -r '.email // "N/A"')
        local profile=$(echo "$user_data" | jq -r '.html_url')

        # Try to get email from user's public events if not available
        if [ "$email" = "N/A" ] || [ "$email" = "null" ]; then
            email=$(gh api "users/$username/events/public" --jq '.[0].payload.commits[0].author.email // "N/A"' 2>/dev/null || echo "N/A")
        fi

        # Format dates
        local created_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$created_at" "+%Y-%m-%d" 2>/dev/null || echo "$created_at")
        local activity_date="Never"
        if [ "$last_activity" != "Never" ] && [ "$last_activity" != "null" ]; then
            activity_date=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$last_activity" "+%Y-%m-%d" 2>/dev/null || echo "$last_activity")
        fi

        echo "\"$login\",\"$name\",\"$email\",\"$created_date\",\"$activity_date\",\"$status\",\"$profile\"" >> "$OUTPUT_FILE"
    done
}

# Main function
main() {
    echo ""
    print_info "GitHub Copilot User Email Export Script"
    echo ""

    # Parse arguments
    parse_args "$@"

    # Check if org is set
    if [ -z "$ORG" ]; then
        print_error "Organization not specified. Use --org YOUR_ORG"
        echo ""
        show_usage
        exit 1
    fi

    # Validate seat status
    if [[ ! "$SEAT_STATUS" =~ ^(all|active|pending)$ ]]; then
        print_error "Invalid status: $SEAT_STATUS. Use: all, active, or pending"
        exit 1
    fi

    # Check GitHub CLI
    check_gh_cli

    echo ""

    # Export Copilot users
    export_copilot_users "$ORG"

    echo ""
    print_success "Export completed!"
    print_info "Output saved to: $OUTPUT_FILE"

    # Count results
    total_users=$(($(wc -l < "$OUTPUT_FILE") - 1))

    if [ $total_users -eq 0 ]; then
        print_warning "No Copilot users found."
        echo ""
        print_info "Possible reasons:"
        echo "  - Organization has no Copilot subscription"
        echo "  - No seats have been assigned"
        echo "  - You don't have permission to view billing information"
        exit 0
    fi

    users_with_email=$(grep -v "\"N/A\"" "$OUTPUT_FILE" | grep -v "username,name,email" | wc -l | tr -d ' ')

    echo ""
    print_info "Total Copilot users: $total_users"
    print_info "Users with email addresses: $users_with_email"

    if [ "$users_with_email" -lt "$total_users" ]; then
        echo ""
        print_warning "Some users don't have public email addresses."
        print_warning "You may need to:"
        echo "  1. Contact them via GitHub directly"
        echo "  2. Use your organization's email directory"
        echo "  3. Ask them to make their email public on GitHub"
    fi

    echo ""
    print_success "Next steps:"
    echo "  1. Open $OUTPUT_FILE in Excel, Numbers, or any CSV viewer"
    echo "  2. Import into your email client (Mail, Outlook, etc.)"
    echo "  3. Use for mail merge or bulk email campaigns"
    echo ""
}

# Run main function
main "$@"
