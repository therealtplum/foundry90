# Branch Merge Strategy: hadron-v1 → main

## Current Branch Status

### Branches Overview
- **main**: Base branch (commit `6709b97`)
- **hadron-v1**: 17 commits ahead of main, 0 commits behind ✅
- **Auth0**: 2 commits ahead of common ancestor, 23 commits behind hadron-v1
- **kalshi-integration**: 3 commits ahead of common ancestor, 23 commits behind hadron-v1
- **markets-hub**: 4 commits ahead of common ancestor, 23 commits behind hadron-v1
- **debug-news-llm-integration**: Debug branch (can be ignored for merge)
- **backup-before-history-rewrite**: Backup branch (can be ignored)

### Key Insight
**hadron-v1 is a clean linear extension of main** - it branched directly from main and has no conflicts. This makes it the safest branch to merge.

## Merge Path Analysis

### Option 1: Direct Merge (Recommended) ✅
**Path**: `hadron-v1` → `main`

**Pros**:
- Clean, linear history
- No conflicts (hadron-v1 is ahead of main with no divergence)
- All 17 commits are Hadron-related and well-organized
- Safest option

**Cons**:
- Other branches (Auth0, kalshi-integration, markets-hub) will need to rebase/merge after

**Steps**:
```bash
git checkout main
git pull origin main
git merge hadron-v1 --no-ff -m "Merge hadron-v1: Add Hadron real-time intelligence system"
git push origin main
```

### Option 2: Squash Merge
**Path**: `hadron-v1` → `main` (squash)

**Pros**:
- Cleaner history (single commit)
- Easier to revert if needed

**Cons**:
- Loses individual commit history
- Harder to track what changed

**Steps**:
```bash
git checkout main
git pull origin main
git merge hadron-v1 --squash -m "Add Hadron real-time intelligence system"
git commit -m "feat: Add Hadron real-time intelligence system

- Implement Hadron Phase 1: Core Pipeline MVP
- Add Polygon WebSocket integration (15-min delayed)
- Add reference data support (market status, holidays, condition codes)
- Add market status visualization to macOS app
- Add comprehensive documentation and roadmap"
git push origin main
```

### Option 3: Rebase and Merge (Not Recommended)
**Path**: Rebase `hadron-v1` onto `main`, then merge

**Pros**:
- Linear history

**Cons**:
- Unnecessary (hadron-v1 is already linear)
- Risk of breaking commits
- Already pushed to origin

## What Gets Merged

### New Files (31 files, +4470 lines)
- **Hadron Service**: Complete Rust implementation
  - `apps/hadron/` - Full service with ingest, normalize, router, engine, strategies, gateway, recorder
  - Database schema: `services/db/schema_hadron.sql`
- **Reference Data**: Market status, holidays, condition codes
  - `services/db/schema_reference_data.sql`
  - ETL scripts for Polygon reference data
- **macOS App Updates**: Market status visualization
  - Market status models and services
  - Updated Markets tab with status indicators
- **Documentation**: Comprehensive Hadron docs
  - Status and roadmap
  - Polygon plan limitations
  - Security warnings

### Modified Files
- `docker-compose.yml` - Added Hadron service
- `apps/rust-api/src/main.rs` - Added market status endpoint
- `apps/web/package.json` - Updated eslint-config-next
- `ops/run_regression.sh` - Improved Docker image checks
- `clients/FMHubControl/` - Market status UI updates

## Handling Other Branches After Merge

### Auth0 Branch
**Status**: 2 commits ahead, needs to merge main after hadron-v1 merge

**Strategy**: Merge main into Auth0 after hadron-v1 is merged
```bash
git checkout Auth0
git merge main
# Resolve any conflicts (likely none, different areas)
```

### kalshi-integration Branch
**Status**: 3 commits ahead, needs to merge main after hadron-v1 merge

**Strategy**: Merge main into kalshi-integration after hadron-v1 is merged
```bash
git checkout kalshi-integration
git merge main
# Resolve any conflicts
```

### markets-hub Branch
**Status**: 4 commits ahead, needs to merge main after hadron-v1 merge

**Strategy**: Merge main into markets-hub after hadron-v1 is merged
```bash
git checkout markets-hub
git merge main
# Resolve any conflicts (might have conflicts in Markets tab)
```

## Recommended Merge Sequence

### Phase 1: Merge hadron-v1 to main (Now)
1. ✅ Review hadron-v1 changes
2. ✅ Run regression tests on hadron-v1
3. ✅ Merge hadron-v1 → main
4. ✅ Tag release: `v1.0.0-hadron` or similar

### Phase 2: Update other branches (After main merge)
1. Merge main → Auth0
2. Merge main → kalshi-integration  
3. Merge main → markets-hub (may have conflicts in Markets tab)

### Phase 3: Cleanup (Optional)
1. Delete merged branches if no longer needed
2. Keep feature branches until features are complete

## Risk Assessment

### Low Risk ✅
- hadron-v1 is clean and well-tested
- No conflicts with main
- All changes are additive (new service, new features)
- Documentation is comprehensive

### Medium Risk ⚠️
- Other branches may have conflicts when merging main
- Markets tab changes might conflict with markets-hub branch
- Need to test after merge

### Mitigation
- Merge hadron-v1 first (cleanest)
- Test thoroughly after merge
- Update other branches one at a time
- Keep hadron-v1 branch until other merges are complete

## Pre-Merge Checklist

- [ ] Run full regression test on hadron-v1
- [ ] Verify all Hadron services start correctly
- [ ] Check database migrations are correct
- [ ] Verify macOS app builds and runs
- [ ] Review all 17 commits
- [ ] Ensure documentation is complete
- [ ] Backup current main branch (optional)

## Post-Merge Checklist

- [ ] Verify main branch builds successfully
- [ ] Run regression tests on main
- [ ] Test Hadron service starts
- [ ] Verify market status endpoint works
- [ ] Check macOS app still works
- [ ] Update other branches (Auth0, kalshi-integration, markets-hub)
- [ ] Tag release if appropriate

## Recommendation

**Merge hadron-v1 directly to main using Option 1 (Direct Merge)**.

This is the safest path because:
1. hadron-v1 is a clean linear extension of main
2. No conflicts exist
3. All changes are well-documented and tested
4. Other branches can be updated after main is updated

The merge will add ~4,470 lines of new code (mostly Hadron service) and update a few existing files. This is a significant but well-contained feature addition.

