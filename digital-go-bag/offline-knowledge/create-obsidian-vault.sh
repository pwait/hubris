#!/bin/bash
#
# OBSIDIAN SURVIVAL VAULT CREATOR
# Creates an offline-first knowledge vault with useful templates
#
# Obsidian is a Markdown-based knowledge base that works 100% offline.
# All data is stored as plain text files - no database, no cloud required.
#

set -euo pipefail

VAULT_DIR="${1:-${HOME}/survival-vault}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_color() {
    echo -e "${1}${2}${NC}"
}

create_vault() {
    print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
    print_color "$CYAN" "║           CREATING SURVIVAL KNOWLEDGE VAULT                    ║"
    print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
    echo ""

    mkdir -p "$VAULT_DIR"/{.obsidian,templates,journal,resources,skills,inventory,contacts,maps,medical,communications,food-water,shelter,security}

    print_color "$BLUE" "Creating vault structure..."

    # Create Obsidian settings
    create_obsidian_config

    # Create templates
    create_templates

    # Create starter content
    create_starter_content

    print_color "$GREEN" "Vault created at: $VAULT_DIR"
    echo ""
    print_color "$BLUE" "To use:"
    echo "  1. Install Obsidian from https://obsidian.md"
    echo "  2. Open folder as vault: $VAULT_DIR"
    echo "  3. Start documenting!"
}

create_obsidian_config() {
    # Core plugins config
    cat > "$VAULT_DIR/.obsidian/core-plugins.json" << 'EOF'
["file-explorer","global-search","switcher","graph","backlink","outgoing-link","tag-pane","page-preview","daily-notes","templates","note-composer","command-palette","editor-status","markdown-importer","outline","file-recovery"]
EOF

    # App settings
    cat > "$VAULT_DIR/.obsidian/app.json" << 'EOF'
{
  "alwaysUpdateLinks": true,
  "newFileLocation": "folder",
  "newFileFolderPath": "journal",
  "attachmentFolderPath": "resources/attachments",
  "showLineNumber": true,
  "spellcheck": true
}
EOF

    # Daily notes settings
    cat > "$VAULT_DIR/.obsidian/daily-notes.json" << 'EOF'
{
  "folder": "journal",
  "template": "templates/daily-note",
  "format": "YYYY-MM-DD"
}
EOF

    # Templates settings
    cat > "$VAULT_DIR/.obsidian/templates.json" << 'EOF'
{
  "folder": "templates"
}
EOF
}

create_templates() {
    # Daily note template
    cat > "$VAULT_DIR/templates/daily-note.md" << 'EOF'
# {{date}}

## Weather & Conditions
- Temperature:
- Weather:
- Moon phase:

## Priorities Today
- [ ]
- [ ]
- [ ]

## Resources Status
- Water:
- Food:
- Fuel:
- Power:

## Events & Observations


## People Encountered


## Security Notes


## Tomorrow's Plan


---
*Created: {{time}}*
EOF

    # Person contact template
    cat > "$VAULT_DIR/templates/person.md" << 'EOF'
# Person Name

## Basic Info
- **Met**: {{date}}
- **Location**:
- **Description**:

## Skills/Resources
-

## Reliability Assessment
- Trust level: /10
- Notes:

## Last Contact
- Date:
- Circumstances:

## Tags
#person #contact
EOF

    # Location template
    cat > "$VAULT_DIR/templates/location.md" << 'EOF'
# Location Name

## Coordinates
- Lat/Long:
- Grid ref:
- Distance from base:

## Description


## Resources Available
- Water:
- Shelter:
- Food:
- Other:

## Hazards


## Access Routes


## Last Visited
{{date}}

#location
EOF

    # Inventory item template
    cat > "$VAULT_DIR/templates/inventory-item.md" << 'EOF'
# Item Name

## Details
- **Quantity**:
- **Location**:
- **Condition**:
- **Acquired**: {{date}}

## Uses


## Maintenance Notes


## Related Items


#inventory
EOF

    # Skill/procedure template
    cat > "$VAULT_DIR/templates/skill.md" << 'EOF'
# Skill/Procedure Name

## Overview


## Requirements
-

## Steps
1.
2.
3.

## Safety Notes


## Related Skills


## References


#skill #howto
EOF

    # Medical incident template
    cat > "$VAULT_DIR/templates/medical-incident.md" << 'EOF'
# Medical Incident - {{date}}

## Patient
- Name:
- Age:

## Symptoms/Injury


## Assessment


## Treatment Given


## Medications Used


## Outcome


## Follow-up Needed


#medical #health
EOF
}

create_starter_content() {
    # Main index/dashboard
    cat > "$VAULT_DIR/Dashboard.md" << 'EOF'
# Survival Knowledge Base

## Quick Links
- [[journal/|Daily Journal]]
- [[inventory/|Inventory]]
- [[contacts/|People & Contacts]]
- [[maps/|Maps & Locations]]
- [[skills/|Skills & How-To]]
- [[medical/|Medical]]
- [[food-water/|Food & Water]]
- [[shelter/|Shelter]]
- [[communications/|Communications]]
- [[security/|Security]]

## Current Status
> Update this section regularly

- **Location**:
- **Group size**:
- **Days since event**:

## Critical Resources
| Resource | Status | Days Remaining |
|----------|--------|----------------|
| Water    |        |                |
| Food     |        |                |
| Fuel     |        |                |
| Medical  |        |                |
| Power    |        |                |

## Recent Journal Entries
```dataview
LIST FROM "journal" SORT file.name DESC LIMIT 5
```

## Priority Tasks
- [ ]
- [ ]
- [ ]

---
*Open daily notes with Ctrl/Cmd + P → "Open today's daily note"*
EOF

    # Water guide
    cat > "$VAULT_DIR/food-water/Water Purification.md" << 'EOF'
# Water Purification Methods

## Boiling
- **Time**: Rolling boil for 1-3 minutes (longer at altitude)
- **Pros**: Kills all pathogens
- **Cons**: Requires fuel, doesn't remove chemicals

## Chemical Treatment
### Chlorine (Bleach)
- 2 drops per liter of clear water
- 4 drops per liter of cloudy water
- Wait 30 minutes before drinking
- Use unscented bleach only (5-6% sodium hypochlorite)

### Iodine
- 5 drops per liter clear water
- 10 drops per liter cloudy water
- Wait 30+ minutes
- Not for pregnant women or thyroid issues

## Filtration
- Removes sediment and many pathogens
- Ceramic filters: 0.2-0.5 micron
- Activated carbon: improves taste, removes chemicals
- Always filter BEFORE chemical treatment

## Solar Disinfection (SODIS)
- Fill clear PET bottles
- Expose to direct sunlight for 6+ hours
- 2 days if cloudy
- Only works for clear water

## Signs of Contamination
- Unusual color or smell
- Oily film on surface
- Dead animals nearby
- Industrial sites upstream

#water #survival #skill
EOF

    # First aid basics
    cat > "$VAULT_DIR/medical/First Aid Basics.md" << 'EOF'
# First Aid Basics

## Primary Assessment (DR ABC)
1. **D**anger - Is it safe?
2. **R**esponse - Are they conscious?
3. **A**irway - Is it clear?
4. **B**reathing - Are they breathing?
5. **C**irculation - Is there severe bleeding?

## Bleeding Control
1. Apply direct pressure with clean cloth
2. Elevate the wound above heart level
3. Apply pressure to pressure points if needed
4. Tourniquet as LAST resort for life-threatening limb bleeding
   - Note time applied
   - Do not remove once applied

## CPR (Adult)
1. 30 chest compressions (2 inches deep, 100-120/min)
2. 2 rescue breaths
3. Repeat until help arrives or exhaustion

## Shock
Signs: Pale skin, rapid breathing, confusion, weakness

Treatment:
1. Lay person down, elevate legs
2. Keep warm
3. Do NOT give food or water
4. Treat underlying cause

## Burns
1. Cool with running water 10-20 minutes
2. Remove jewelry near burn
3. Cover with clean, non-stick dressing
4. Do NOT pop blisters or apply butter/oil

## Fractures
1. Immobilize above and below the break
2. Splint in position found
3. Check circulation beyond injury
4. Apply cold pack (not directly on skin)

#medical #firstaid #skill
EOF

    # Communications guide
    cat > "$VAULT_DIR/communications/Radio Basics.md" << 'EOF'
# Radio Communications Basics

## FRS/GMRS Radios (Walkie-Talkies)
- Range: 0.5-2 miles typical
- Channels 1-7: Shared FRS/GMRS
- Channel 1: Common emergency channel
- GMRS requires license (but in emergency, use anyway)

## CB Radio
- Channel 9: Emergency channel
- Channel 19: Highway/truckers
- Range: 1-5 miles

## Amateur (Ham) Radio
- 146.520 MHz: 2m calling frequency
- 52.525 MHz: 6m calling frequency
- 446.000 MHz: 70cm calling frequency
- License normally required

## Phonetic Alphabet
| A - Alpha   | N - November |
| B - Bravo   | O - Oscar    |
| C - Charlie | P - Papa     |
| D - Delta   | Q - Quebec   |
| E - Echo    | R - Romeo    |
| F - Foxtrot | S - Sierra   |
| G - Golf    | T - Tango    |
| H - Hotel   | U - Uniform  |
| I - India   | V - Victor   |
| J - Juliet  | W - Whiskey  |
| K - Kilo    | X - X-ray    |
| L - Lima    | Y - Yankee   |
| M - Mike    | Z - Zulu     |

## Signal Reports
- "Lima Charlie" = Loud and Clear
- "Read you 5 by 5" = Perfect reception
- "Say again" = Repeat message

## Distress Calls
- "MAYDAY MAYDAY MAYDAY" - Life threatening
- "PAN PAN PAN PAN" - Urgent but not life threatening

#communications #radio #skill
EOF

    # Security basics
    cat > "$VAULT_DIR/security/Security Basics.md" << 'EOF'
# Security Basics

## Situational Awareness
- Always know your exits
- Observe before entering new areas
- Trust your instincts
- Avoid predictable patterns

## Location Security
### Layers of Defense
1. **Observation** - See them coming
2. **Warning** - Know when they arrive
3. **Delay** - Slow their approach
4. **Defense** - Protected positions

### Early Warning
- Dogs (best natural alarm)
- Gravel paths (noise)
- Trip wires with cans/bells
- Motion lights (if power available)

## Information Security
- Need-to-know basis
- Don't reveal:
  - Exact location
  - Resources/supplies
  - Number of people
  - Defensive capabilities

## OPSEC Rules
1. Look poor and uninteresting
2. Avoid displaying weapons openly
3. Maintain gray man appearance
4. Stagger arrivals/departures
5. Don't discuss plans in public

## Night Security
- Minimize light discipline
- Establish watch rotation
- Pre-plan rally points
- Keep essentials ready to go

#security #safety
EOF

    # Inventory starter
    cat > "$VAULT_DIR/inventory/Inventory Index.md" << 'EOF'
# Inventory Index

## Categories
- [[Water & Filtration]]
- [[Food & Cooking]]
- [[Shelter & Bedding]]
- [[Medical Supplies]]
- [[Tools]]
- [[Communications Equipment]]
- [[Power & Lighting]]
- [[Defense]]
- [[Clothing]]
- [[Documents]]

## Quick Count
| Category | Items | Last Updated |
|----------|-------|--------------|
| Water    |       |              |
| Food     |       |              |
| Medical  |       |              |
| Tools    |       |              |

## Critical Items to Acquire


## Barter Items


#inventory
EOF

    # Contacts index
    cat > "$VAULT_DIR/contacts/Contacts Index.md" << 'EOF'
# Contacts Index

## Trusted Contacts


## Acquaintances


## Traders/Resources


## Medical Skills


## Technical Skills


## Locations of Interest
![[maps/Locations Index]]

#contacts #people
EOF

    # Maps index
    cat > "$VAULT_DIR/maps/Locations Index.md" << 'EOF'
# Locations Index

## Base Locations


## Water Sources


## Food Sources


## Safe Houses


## Danger Zones


## Trade Posts


## Medical Facilities


#maps #locations
EOF

    print_color "$GREEN" "Created starter content with templates"
}

# Main
create_vault

echo ""
print_color "$CYAN" "╔════════════════════════════════════════════════════════════════╗"
print_color "$CYAN" "║                    VAULT READY                                  ║"
print_color "$CYAN" "╚════════════════════════════════════════════════════════════════╝"
echo ""
print_color "$WHITE" "Structure:"
find "$VAULT_DIR" -type d -not -path "*/\.*" | sed "s|$VAULT_DIR|.|" | head -20
echo ""
print_color "$BLUE" "Next steps:"
echo "  1. Download Obsidian: https://obsidian.md"
echo "  2. Open as vault: $VAULT_DIR"
echo "  3. Customize and add your knowledge!"
echo ""
print_color "$YELLOW" "Tip: Obsidian works 100% offline - all data is local Markdown files"
