# fff-snacks.nvim - merged fork management
#
# Upstreams:
#   - upstream (madmaxieee) = base, has live_grep
#   - nikbrunner = frecency indicators, git icons, config
#
# Strategy: rebase nikbrunner features onto madmaxieee base

# Fetch all remotes
fetch:
    jj git fetch --all-remotes
    @echo ""
    @echo "=== Upstream status ==="
    jj log -r 'main@upstream | main@nikbrunner' --no-graph -T 'separate(" ", bookmarks, commit_id.short(), description.first_line()) ++ "\n"'

# Show divergence between upstreams
divergence:
    @echo "=== madmaxieee (upstream) ===" 
    jj log -r 'ancestors(main@upstream, 10)'
    @echo ""
    @echo "=== nikbrunner ==="
    jj log -r 'ancestors(main@nikbrunner, 10)'
    @echo ""
    @echo "=== Common ancestor ==="
    jj log -r 'heads(ancestors(main@upstream) & ancestors(main@nikbrunner))' --no-graph

# Show what's new in each upstream since last sync
whats-new:
    @echo "=== New in madmaxieee (upstream) ==="
    jj log -r 'main@upstream ~ ancestors(main@origin)' --no-graph
    @echo ""
    @echo "=== New in nikbrunner ==="
    jj log -r 'main@nikbrunner ~ ancestors(main@origin)' --no-graph

# Show current state of main bookmark
status:
    jj log -r 'main | main@origin | main@upstream | main@nikbrunner' --no-graph
    @echo ""
    jj bookmark list

# Show commits unique to nikbrunner (candidates for cherry-pick)
nikbrunner-commits:
    jj log -r 'main@nikbrunner ~ main@upstream'

# Show commits unique to madmaxieee/upstream
upstream-commits:
    jj log -r 'main@upstream ~ main@nikbrunner'

# Rebase main onto latest upstream (madmaxieee)
rebase-onto-upstream:
    jj rebase -b main -d main@upstream

# Cherry-pick a specific commit from nikbrunner
cherry-pick rev:
    jj new main
    jj squash --from {{rev}} -u

# Cherry-pick all nikbrunner commits onto current main
cherry-pick-nikbrunner:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Cherry-picking nikbrunner commits onto main..."
    
    # Get commits unique to nikbrunner, oldest first
    commits=$(jj log -r 'main@nikbrunner ~ ancestors(main@upstream)' --no-graph -T 'commit_id.short() ++ "\n"' | tac)
    
    for commit in $commits; do
        echo "Cherry-picking $commit..."
        jj new main -m "wip: cherry-pick from nikbrunner"
        jj squash --from "$commit" -u
        jj bookmark set main
    done
    
    echo "Done. Review with: just log"

# Interactive: review each nikbrunner commit and decide
review-nikbrunner:
    #!/usr/bin/env bash
    set -euo pipefail
    
    commits=$(jj log -r 'main@nikbrunner ~ ancestors(main@upstream)' --no-graph -T 'commit_id.short() ++ "\n"' | tac)
    
    for commit in $commits; do
        echo ""
        echo "=========================================="
        jj show "$commit"
        echo "=========================================="
        echo ""
        read -p "Cherry-pick this commit? [y/n/q] " choice
        case "$choice" in
            y|Y)
                jj new main -m "wip: cherry-pick $commit"
                jj squash --from "$commit" -u
                jj bookmark set main
                echo "✓ Cherry-picked $commit"
                ;;
            n|N)
                echo "Skipped $commit"
                ;;
            q|Q)
                echo "Quitting"
                exit 0
                ;;
        esac
    done

# Show conflicts in working copy
conflicts:
    jj resolve --list

# Open conflict resolution
resolve:
    jj resolve

# After resolving, continue
continue:
    jj squash

# Push main to origin (your fork)
push:
    jj git push -b main

# Push with force (after rebase)
push-force:
    jj git push -b main --allow-new

# Log recent history
log:
    jj log -r 'ancestors(main, 15)'

# Full graph view
graph:
    jj log -r 'all()'

# Diff between upstreams
diff-upstreams:
    jj diff --from main@upstream --to main@nikbrunner

# Diff specific file between upstreams  
diff-file file:
    jj diff --from main@upstream --to main@nikbrunner -- {{file}}

# Show what would change merging nikbrunner into current main
preview-merge:
    jj diff --from main --to main@nikbrunner

# Abandon working copy changes and start fresh
reset:
    jj abandon @
    jj new main

# Create a new feature branch
branch name:
    jj new main -m "{{name}}"
    jj bookmark create {{name}}

# Initial setup: apply nikbrunner features onto madmaxieee base
initial-merge:
    #!/usr/bin/env bash
    set -euo pipefail
    
    echo "Setting main to upstream (madmaxieee)..."
    jj bookmark set main -r main@upstream
    
    echo ""
    echo "nikbrunner commits to cherry-pick:"
    jj log -r 'main@nikbrunner ~ ancestors(main@upstream)' --no-graph
    
    echo ""
    echo "Run 'just review-nikbrunner' to interactively cherry-pick"
    echo "Or 'just cherry-pick-nikbrunner' to cherry-pick all"
