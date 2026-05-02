#!/bin/bash
# quick-claude - Quick launcher to get coding in your repos
# Usage: source quick-claude.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env if it exists
if [[ -f "$SCRIPT_DIR/.env" ]]; then
    source "$SCRIPT_DIR/.env"
fi

# Default repos directory
REPOS_DIR="${REPOS_DIR:-$HOME/repos}"

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

# Sort mode constants
[[ -z "${SORT_BY_DATE+x}" ]] && readonly SORT_BY_DATE=0
[[ -z "${SORT_BY_NAME+x}" ]] && readonly SORT_BY_NAME=1
sort_mode=$SORT_BY_DATE

# Check if repos directory exists
if [[ ! -d "$REPOS_DIR" ]]; then
    echo -e "${YELLOW}Directory not found: $REPOS_DIR${NC}"
    echo -e "${DIM}Set REPOS_DIR in $SCRIPT_DIR/.env${NC}"
    return 1 2>/dev/null || exit 1
fi

# Gather repos with their last activity date
declare -a repos=()
declare -a dates=()
declare -a display_dates=()

for dir in "$REPOS_DIR"/*/; do
    [[ -d "$dir" ]] || continue
    repo_name=$(basename "$dir")

    # Try to get last commit date if it's a git repo
    if [[ -d "$dir/.git" ]]; then
        timestamp=$(git -C "$dir" log -1 --format=%ct 2>/dev/null)
        if [[ -n "$timestamp" ]]; then
            display_date=$(date -d "@$timestamp" "+%Y-%m-%d" 2>/dev/null || date -r "$timestamp" "+%Y-%m-%d" 2>/dev/null)
        else
            timestamp=$(stat -c %Y "$dir" 2>/dev/null || stat -f %m "$dir" 2>/dev/null)
            display_date="no commits"
        fi
    else
        timestamp=$(stat -c %Y "$dir" 2>/dev/null || stat -f %m "$dir" 2>/dev/null)
        display_date="not git"
    fi

    repos+=("$repo_name")
    dates+=("$timestamp")
    display_dates+=("$display_date")
done

# Check if we found any repos
if [[ ${#repos[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No repos found in $REPOS_DIR${NC}"
    return 1 2>/dev/null || exit 1
fi

# Sort by date (oldest first, so newest appears at bottom of screen)
indices=($(for i in "${!dates[@]}"; do echo "$i ${dates[$i]}"; done | sort -k2 -n | cut -d' ' -f1))

# Find max repo name length for alignment
max_name_len=0
for name in "${repos[@]}"; do
    [[ ${#name} -gt $max_name_len ]] && max_name_len=${#name}
done

# Build sorted list (most recent first for display)
total=${#indices[@]}
declare -a sorted_repos=()
declare -a sorted_dates=()
for ((j=total-1; j>=0; j--)); do
    i="${indices[$j]}"
    sorted_repos+=("${repos[$i]}")
    sorted_dates+=("${display_dates[$i]}")
done

# Search state
search_query=""
declare -a filtered_indices=()
filtered_total=0

# Store original arrays for re-sorting (parallel arrays: index links them)
declare -a original_repos=("${sorted_repos[@]}")
declare -a original_dates=("${sorted_dates[@]}")
declare -a original_timestamps=()
# Build timestamps in same order as sorted_repos (most recent first)
for ((j=total-1; j>=0; j--)); do
    i="${indices[$j]}"
    original_timestamps+=("${dates[$i]}")
done

# Viewport state for scrolling when list exceeds terminal height
viewport_size=0
viewport_start=0
overflow=0
displayed_rows=0

# Compute viewport size from terminal height. Reserves room for the 4-line
# header plus a couple of lines of breathing space below the menu so the
# active selection never scrolls off-screen.
calc_viewport() {
    local term_rows=${LINES:-0}
    if [[ $term_rows -le 0 ]]; then
        term_rows=$(tput lines 2>/dev/null)
        [[ -z $term_rows || $term_rows -le 0 ]] && term_rows=30
    fi
    local reserved=6
    local avail=$((term_rows - reserved))
    [[ $avail -lt 5 ]] && avail=5

    if [[ $total -le $avail ]]; then
        viewport_size=$total
        overflow=0
        displayed_rows=$total
    else
        viewport_size=$avail
        overflow=1
        # +2 for the top/bottom "N more" indicator lines
        displayed_rows=$((avail + 2))
    fi
}

# Slide viewport_start so `current` stays within the visible window
ensure_visible() {
    if [[ $current -lt $viewport_start ]]; then
        viewport_start=$current
    elif [[ $current -ge $((viewport_start + viewport_size)) ]]; then
        viewport_start=$((current - viewport_size + 1))
    fi
    [[ $viewport_start -lt 0 ]] && viewport_start=0
    local max_start=$((total - viewport_size))
    [[ $max_start -lt 0 ]] && max_start=0
    [[ $viewport_start -gt $max_start ]] && viewport_start=$max_start
}

# Function to apply current sort mode
apply_sort() {
    if [[ $sort_mode -eq $SORT_BY_DATE ]]; then
        # Sort by timestamp descending (most recent first)
        local sort_indices=($(for i in "${!original_timestamps[@]}"; do
            echo "$i ${original_timestamps[$i]}"
        done | sort -k2 -nr | cut -d' ' -f1))

        sorted_repos=()
        sorted_dates=()
        for i in "${sort_indices[@]}"; do
            sorted_repos+=("${original_repos[$i]}")
            sorted_dates+=("${original_dates[$i]}")
        done
    elif [[ $sort_mode -eq $SORT_BY_NAME ]]; then
        # Sort alphabetically by name (case-insensitive)
        local sort_indices=($(for i in "${!original_repos[@]}"; do
            echo "$i ${original_repos[$i]}"
        done | sort -k2 -f | cut -d' ' -f1))

        sorted_repos=()
        sorted_dates=()
        for i in "${sort_indices[@]}"; do
            sorted_repos+=("${original_repos[$i]}")
            sorted_dates+=("${original_dates[$i]}")
        done
    fi
}

# Function to update filtered indices based on search query
update_filter() {
    filtered_indices=()
    if [[ -z "$search_query" ]]; then
        for ((i=0; i<total; i++)); do
            filtered_indices+=($i)
        done
    else
        local query_lower="${search_query,,}"
        for ((i=0; i<total; i++)); do
            local name_lower="${sorted_repos[$i],,}"
            if [[ "$name_lower" == "$query_lower"* ]]; then
                filtered_indices+=($i)
            fi
        done
    fi
    filtered_total=${#filtered_indices[@]}
}

# Function to get sort mode label
get_sort_label() {
    if [[ $sort_mode -eq $SORT_BY_DATE ]]; then
        echo "date"
    else
        echo "name"
    fi
}

# Function to draw menu
draw_menu() {
    local selected=$1
    local start_line=$2

    if [[ $start_line -gt 0 ]]; then
        printf "\033[%dA" "$displayed_rows"
    fi

    ensure_visible

    # Precompute match status
    local -a is_match=()
    for ((i=0; i<total; i++)); do
        is_match[$i]=0
    done
    if [[ -n "$search_query" ]]; then
        for fi_idx in "${filtered_indices[@]}"; do
            is_match[$fi_idx]=1
        done
    fi

    # Top scroll indicator
    if [[ $overflow -eq 1 ]]; then
        printf "\r\033[K"
        if [[ $viewport_start -gt 0 ]]; then
            local hidden_above=$viewport_start
            local matches_above=0
            if [[ -n "$search_query" ]]; then
                for ((mi=0; mi<viewport_start; mi++)); do
                    [[ ${is_match[$mi]} -eq 1 ]] && ((matches_above++))
                done
            fi
            if [[ -n "$search_query" && $matches_above -gt 0 ]]; then
                echo -e "  ${DIM}↑ ${hidden_above} more (${CYAN}${matches_above} match$([[ $matches_above -ne 1 ]] && echo es)${NC}${DIM})${NC}"
            else
                echo -e "  ${DIM}↑ ${hidden_above} more${NC}"
            fi
        else
            printf "\n"
        fi
    fi

    local view_end=$((viewport_start + viewport_size))
    [[ $view_end -gt $total ]] && view_end=$total

    for ((i=viewport_start; i<view_end; i++)); do
        local name="${sorted_repos[$i]}"
        local padded_name=$(printf "%-${max_name_len}s" "$name")
        local num=$((i+1))
        local num_label

        if [[ $num -le 9 ]]; then
            num_label="${DIM}${num}${NC} "
        else
            num_label="  "
        fi

        printf "\r\033[K"

        if [[ -n "$search_query" ]]; then
            local qlen=${#search_query}
            if [[ ${is_match[$i]} -eq 1 ]]; then
                local match_part="${name:0:$qlen}"
                local rest_name="${name:$qlen}"
                local padding=$((max_name_len - ${#name}))
                local pad_str=""
                [[ $padding -gt 0 ]] && pad_str=$(printf "%${padding}s" "")
                if [[ $i -eq $selected ]]; then
                    # Selected match: green arrow, cyan prefix, bold rest
                    echo -e "${num_label}${GREEN}${BOLD}>${NC} ${CYAN}${BOLD}${match_part}${NC}${BOLD}${rest_name}${NC}${pad_str}  ${DIM}(${sorted_dates[$i]})${NC}"
                else
                    # Non-selected match: cyan prefix
                    echo -e "${num_label}  ${CYAN}${match_part}${NC}${rest_name}${pad_str}  ${DIM}(${sorted_dates[$i]})${NC}"
                fi
            else
                # Non-matching: dim everything
                echo -e "${num_label}  ${DIM}${padded_name}  (${sorted_dates[$i]})${NC}"
            fi
        else
            if [[ $i -eq $selected ]]; then
                echo -e "${num_label}${GREEN}${BOLD}>${NC} ${BOLD}${padded_name}${NC}  ${DIM}(${sorted_dates[$i]})${NC}"
            else
                echo -e "${num_label}  ${padded_name}  ${DIM}(${sorted_dates[$i]})${NC}"
            fi
        fi
    done

    # Bottom scroll indicator
    if [[ $overflow -eq 1 ]]; then
        printf "\r\033[K"
        local hidden_below=$((total - view_end))
        if [[ $hidden_below -gt 0 ]]; then
            local matches_below=0
            if [[ -n "$search_query" ]]; then
                for ((mi=view_end; mi<total; mi++)); do
                    [[ ${is_match[$mi]} -eq 1 ]] && ((matches_below++))
                done
            fi
            if [[ -n "$search_query" && $matches_below -gt 0 ]]; then
                echo -e "  ${DIM}↓ ${hidden_below} more (${CYAN}${matches_below} match$([[ $matches_below -ne 1 ]] && echo es)${NC}${DIM})${NC}"
            else
                echo -e "  ${DIM}↓ ${hidden_below} more${NC}"
            fi
        else
            printf "\n"
        fi
    fi
}

# Function to draw header
draw_header() {
    local sort_label=$(get_sort_label)
    echo ""
    echo -e "${CYAN}${BOLD}Ready to code?${NC}"
    if [[ -n "$search_query" ]]; then
        echo -e "${DIM}Search:${NC} ${BOLD}${search_query}${NC}${DIM}▌${NC}"
    else
        echo -e "${DIM}Type to search, ↑/↓ 1-9 to select, / to sort [${sort_label}]:${NC}"
    fi
    echo ""
}

update_filter
calc_viewport
draw_header

current=0
draw_menu $current 0

printf "\033[?25l"

cleanup() {
    printf "\033[?25h"
}
trap cleanup EXIT

while true; do
    read -rsn1 key

    if [[ $key == $'\033' ]]; then
        read -rsn2 -t 0.1 key
        if [[ -z $key ]]; then
            # Bare escape
            if [[ -n "$search_query" ]]; then
                # Clear search
                search_query=""
                update_filter
                current=0
                printf "\033[%dA" "$((displayed_rows + 4))"
                draw_header
                draw_menu $current 0
            else
                # Exit
                printf "\033[?25h"
                trap - EXIT
                echo ""
                return 0 2>/dev/null || exit 0
            fi
        else
            case "$key" in
                '[A')
                    # Up arrow
                    if [[ -n "$search_query" && $filtered_total -gt 0 ]]; then
                        # Navigate to previous match
                        prev=-1
                        for ((fi=filtered_total-1; fi>=0; fi--)); do
                            if [[ ${filtered_indices[$fi]} -lt $current ]]; then
                                prev=${filtered_indices[$fi]}
                                break
                            fi
                        done
                        [[ $prev -ge 0 ]] && current=$prev
                    else
                        ((current > 0)) && ((current--))
                    fi
                    ;;
                '[B')
                    # Down arrow
                    if [[ -n "$search_query" && $filtered_total -gt 0 ]]; then
                        # Navigate to next match
                        next=-1
                        for ((fi=0; fi<filtered_total; fi++)); do
                            if [[ ${filtered_indices[$fi]} -gt $current ]]; then
                                next=${filtered_indices[$fi]}
                                break
                            fi
                        done
                        [[ $next -ge 0 ]] && current=$next
                    else
                        ((current < total - 1)) && ((current++))
                    fi
                    ;;
            esac
            draw_menu $current 1
        fi
    elif [[ $key == '' ]]; then
        # Enter - select current (only if valid)
        if [[ -z "$search_query" || $filtered_total -gt 0 ]]; then
            break
        fi
    elif [[ $key == '/' ]]; then
        # Toggle sort mode
        if [[ $sort_mode -eq $SORT_BY_DATE ]]; then
            sort_mode=$SORT_BY_NAME
        else
            sort_mode=$SORT_BY_DATE
        fi
        apply_sort
        search_query=""
        update_filter
        current=0
        printf "\033[%dA" "$((displayed_rows + 4))"
        draw_header
        draw_menu $current 0
    elif [[ $key == $'\177' || $key == $'\b' ]]; then
        # Backspace - remove last search character
        if [[ -n "$search_query" ]]; then
            search_query="${search_query%?}"
            update_filter
            if [[ -n "$search_query" && $filtered_total -gt 0 ]]; then
                current=${filtered_indices[0]}
            elif [[ -z "$search_query" ]]; then
                current=0
            fi
            printf "\033[%dA" "$((displayed_rows + 4))"
            draw_header
            draw_menu $current 0
        fi
    elif [[ -z "$search_query" && $key =~ ^[1-9]$ ]]; then
        # Number shortcut (only when not searching)
        target=$((key - 1))
        if [[ $target -lt $total ]]; then
            current=$target
            break
        fi
    elif [[ $key =~ ^[a-zA-Z0-9._-]$ ]]; then
        # Type-to-search: append character to search query
        search_query+="$key"
        update_filter
        if [[ $filtered_total -eq 1 ]]; then
            # Exact single match - auto-select
            current=${filtered_indices[0]}
            break
        elif [[ $filtered_total -gt 0 ]]; then
            current=${filtered_indices[0]}
        fi
        printf "\033[%dA" "$((displayed_rows + 4))"
        draw_header
        draw_menu $current 0
    fi
done

printf "\033[?25h"
trap - EXIT

selected="${sorted_repos[$current]}"
target_dir="$REPOS_DIR/$selected"

echo ""
echo -e "${DIM}Jumping into ${selected}...${NC}"
echo ""

cd "$target_dir" || { echo "Failed to cd"; return 1 2>/dev/null || exit 1; }

if [[ -n "$QUICK_CLAUDE_ZELLIJ" ]]; then
    unset QUICK_CLAUDE_ZELLIJ
    zellij -s "${selected}_$(date +%Y-%m-%d_%H:%M:%S)" -n claude
else
    claude
fi
