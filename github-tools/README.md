# GitHub Tools

Command-line utilities for managing and exporting data from GitHub.

## Prerequisites

### Install GitHub CLI (macOS)

```bash
brew install gh
```

Or download from: https://cli.github.com/

### Authenticate

```bash
gh auth login
```

Follow the prompts to authenticate with your GitHub account.

## Scripts

### 1. Export Copilot Users (`export-copilot-users.sh`)

Export email addresses of all users with GitHub Copilot seats in your organization.

**Requirements:**
- Organization admin access
- GitHub CLI with `manage_billing:copilot` scope

**Basic Usage:**

```bash
# Export all Copilot users
./export-copilot-users.sh --org YOUR_ORG_NAME

# Export only active users
./export-copilot-users.sh --org YOUR_ORG_NAME --status active

# Save to custom file
./export-copilot-users.sh --org YOUR_ORG_NAME --file my-copilot-users.csv
```

**Output:** CSV file with columns:
- `username` - GitHub username
- `name` - Full name
- `email` - Email address (if public)
- `seat_created` - When Copilot seat was assigned
- `last_activity` - Last time user used Copilot
- `status` - Seat status (active, pending_cancellation)
- `profile_url` - GitHub profile URL

**Status Options:**
- `all` (default) - All Copilot users
- `active` - Only active seats
- `pending` - Only seats pending cancellation

**Example:**

```bash
./export-copilot-users.sh --org mycompany
# Output: copilot-users-emails.csv
# Total Copilot users: 42
# Users with email addresses: 38
```

---

### 2. Export GitHub Users (`export-user-emails.sh`)

Export email addresses from various GitHub sources (organizations, repositories, teams).

**Basic Usage:**

```bash
# Export organization members
./export-user-emails.sh --org YOUR_ORG_NAME

# Export repository contributors
./export-user-emails.sh --repo OWNER/REPO_NAME

# Export team members
./export-user-emails.sh --team YOUR_ORG/TEAM_NAME
```

**Output:** CSV file with user information including email addresses.

**Examples:**

```bash
# Organization members
./export-user-emails.sh --org mycompany --file company-members.csv

# Repository contributors
./export-user-emails.sh --repo mycompany/awesome-project

# Team members
./export-user-emails.sh --team mycompany/engineering
```

---

## Common Issues & Solutions

### "Permission denied" or "403 Forbidden"

**Problem:** You don't have sufficient permissions.

**Solution:**
```bash
# Re-authenticate with broader scopes
gh auth login --scopes "admin:org,read:org,manage_billing:copilot"
```

For Copilot data, you must be an **organization admin**.

### "No email addresses found"

**Problem:** Users haven't made their email public on GitHub.

**Solutions:**
1. **Check organization email:** Many orgs have internal email directories
2. **GitHub username to email:** Often username@company.com
3. **Contact via GitHub:** Use GitHub's mention system (@username)
4. **Ask users to update:** Request they make email public in GitHub settings

### "404 Not Found" for Copilot API

**Problem:** Organization doesn't have GitHub Copilot or subscription isn't active.

**Solution:**
1. Verify Copilot subscription at: https://github.com/organizations/YOUR_ORG/settings/copilot
2. Ensure you're using the correct organization name
3. Check if you're authenticated with the right account: `gh auth status`

---

## Using the Exported Data

### Import to Apple Mail (macOS)

1. Open the CSV in **Contacts.app**:
   ```bash
   open copilot-users-emails.csv
   ```
2. File → Import → Select CSV
3. Map columns (Email → Email, Name → Full Name)
4. Create a group for easy bulk emailing

### Import to Outlook

1. Open Outlook
2. File → Import → Import from a file
3. Choose "Comma Separated Values"
4. Select your CSV file
5. Map fields to Outlook contacts

### Mail Merge

1. Open your CSV in Excel or Numbers
2. Create email template in Word/Pages
3. Use mail merge feature with CSV as data source
4. Generate personalized emails for each contact

### Command-line Email (Advanced)

```bash
# Extract just email addresses
awk -F',' 'NR>1 && $3!="N/A" {print $3}' copilot-users-emails.csv > emails.txt

# Send bulk email with mail command
cat emails.txt | while read email; do
    echo "Email body here" | mail -s "Subject" "$email"
done
```

---

## Privacy & Best Practices

- **Respect privacy:** Only use emails for legitimate organization communications
- **GDPR compliance:** Ensure you have legal basis to contact users
- **Opt-out mechanism:** Provide unsubscribe option in bulk emails
- **Rate limiting:** Don't spam - space out bulk communications
- **Test first:** Send to yourself before bulk sending

---

## Troubleshooting

### Check your authentication
```bash
gh auth status
```

### Test API access
```bash
# Test org access
gh api "/orgs/YOUR_ORG/members" | jq '.[0]'

# Test Copilot access
gh api "/orgs/YOUR_ORG/copilot/billing/seats" | jq '.seats[0]'
```

### Enable debug mode
```bash
# Add this to the top of the script
set -x  # Enable debug output
```

---

## Support

For issues or questions:
- GitHub CLI documentation: https://cli.github.com/manual/
- GitHub API documentation: https://docs.github.com/en/rest
- GitHub Copilot billing: https://docs.github.com/en/copilot

---

## License

MIT License - Use freely for your organization's needs.
