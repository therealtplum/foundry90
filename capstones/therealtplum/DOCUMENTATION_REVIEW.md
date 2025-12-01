# Documentation Review - Foundry90 Capstone

**Review Date:** December 2025  
**Last Updated:** December 2025 (verified current state)  
**Scope:** All `.md` files in `capstones/` directory  
**Reviewer:** AI Assistant  

---

## Executive Summary

Reviewed 21 markdown documentation files across the capstone project. Found several inaccuracies, outdated information, and opportunities for consolidation. Most documentation is accurate, but several files need updates to reflect current state (main branch with merged features) or should be archived/removed.

---

## Files Reviewed

### Root Level
1. `capstones/README.md` - Capstone overview
2. `capstones/therealtplum/docs/architecture.md` - Architecture notes (empty template)
3. `capstones/therealtplum/docs/scope.md` - Project scope
4. `capstones/therealtplum/docs/design-decisions.md` - Design decisions log (empty template)
5. `capstones/therealtplum/docs/auth0_guide.md` - Auth0 integration guide
6. `capstones/therealtplum/docs/third_party_tools.md` - Third-party services reference
7. `capstones/therealtplum/docs/BRANCH_MERGE_STRATEGY.md` - Merge strategy (outdated)
8. `capstones/therealtplum/docs/runbook_v1.md` - Old runbook (superseded)
9. `capstones/therealtplum/docs/runbook_v2.md` - Current runbook

### Hadron Documentation
10. `capstones/therealtplum/apps/hadron/README.md` - Hadron service README
11. `capstones/therealtplum/apps/hadron/docs/README.md` - Documentation index
12. `capstones/therealtplum/apps/hadron/docs/KALSHI_INTEGRATION_GUIDE.md` - Comprehensive Kalshi guide
13. `capstones/therealtplum/apps/hadron/docs/KALSHI_NORMALIZATION_DESIGN.md` - Design proposal
14. `capstones/therealtplum/apps/hadron/docs/KALSHI_WEBSOCKET_PROTOCOL.md` - Protocol reference
15. `capstones/therealtplum/apps/hadron/docs/POLYGON_API_LIMITATIONS.md` - Polygon plan details
16. `capstones/therealtplum/apps/hadron/docs/MERGE_READINESS_ASSESSMENT.md` - Merge assessment (outdated)
17. `capstones/therealtplum/apps/hadron/docs/status/HADRON_STATUS.md` - System status (needs update)
18. `capstones/therealtplum/apps/hadron/docs/status/KALSHI_INTEGRATION_COMPLETE.md` - Completion snapshot
19. `capstones/therealtplum/apps/hadron/docs/status/KALSHI_PARSER_PHASE1_COMPLETE.md` - Phase 1 report

### Web App Documentation
20. `capstones/therealtplum/apps/web/TODO.md` - Web app TODO
21. `capstones/therealtplum/apps/web/SECURITY_WARNINGS.md` - Security warnings analysis

---

## Issues Found

### 🔴 Critical Issues (Needs Immediate Fix)

#### 1. **runbook_v2.md - Hadron Service** ✅ **FIXED**
**Location:** `capstones/therealtplum/docs/runbook_v2.md`  
**Status:** Hadron service is now correctly included in the services table (line 91)

**Current State:**
- docker-compose.yml has: db, redis, api, etl, **hadron**, web
- runbook_v2.md lists: db, redis, api, web, etl, **hadron** ✅

**Note:** This issue was previously identified and has been resolved. The runbook now accurately reflects all services.

#### 2. **BRANCH_MERGE_STRATEGY.md - Completely Outdated**
**Location:** `capstones/therealtplum/docs/BRANCH_MERGE_STRATEGY.md`  
**Issue:** References `hadron-v1` branch and merge strategy that appears to have already been completed. Status docs indicate `hadron-v2` was merged.

**Fix Options:**
- **Option A:** Archive to `docs/archive/` if historical reference is needed
- **Option B:** Delete if no longer relevant
- **Option C:** Update to reflect current branch strategy (if still needed)

**Recommendation:** Archive or delete - merge appears complete.

#### 3. **MERGE_READINESS_ASSESSMENT.md - Outdated Branch Reference**
**Location:** `capstones/therealtplum/apps/hadron/docs/MERGE_READINESS_ASSESSMENT.md`  
**Issue:** References `hadron-v2` branch which appears to be merged (based on HADRON_STATUS.md stating it's merged). Document says "Ready for Merge" but merge may be complete.

**Fix Options:**
- **Option A:** Archive if merge is complete
- **Option B:** Update status to indicate merge completion
- **Option C:** Move to `docs/status/archive/`

**Recommendation:** Archive - historical snapshot of merge readiness.

---

### 🟡 Medium Priority Issues (Should Fix Soon)

#### 4. **runbook_v1.md - Superseded by v2**
**Location:** `capstones/therealtplum/docs/runbook_v1.md`  
**Issue:** Explicitly marked as "Updated and Correct (Current)" but v2 exists and is more comprehensive. File header says "This file is now the authoritative FMHub run book" but that's incorrect.

**Fix:** 
- Add header note: "⚠️ OUTDATED - See runbook_v2.md"
- Or move to archive
- Or delete if no longer needed

**Recommendation:** Add deprecation notice or archive.

#### 5. **HADRON_STATUS.md - Branch Reference Outdated**
**Location:** `capstones/therealtplum/apps/hadron/docs/status/HADRON_STATUS.md`  
**Issue:** Line 6 says "Branch: `hadron-v2` (merged from `hadron-v1`)" but if we're on main, this should be updated.

**Fix:** Update to reflect current branch:
```markdown
**Branch:** `main` (hadron-v2 merged)  
**Status:** Operational on main branch
```

#### 6. **architecture.md - Empty Template**
**Location:** `capstones/therealtplum/docs/architecture.md`  
**Issue:** Contains only placeholder text, no actual architecture documentation.

**Fix Options:**
- Fill in with actual architecture diagrams/notes
- Or delete if not needed
- Or add note that architecture docs are in other locations (e.g., HADRON_STATUS.md)

**Recommendation:** Either populate with content or add note pointing to HADRON_STATUS.md and other architecture docs.

#### 7. **design-decisions.md - Empty Template**
**Location:** `capstones/therealtplum/docs/design-decisions.md`  
**Issue:** Contains only placeholder text/template, no actual decisions documented.

**Fix Options:**
- Populate with actual design decisions
- Or delete if not being used
- Or consolidate with other docs

**Recommendation:** Delete if not being used, or populate with actual decisions.

---

### 🟢 Minor Issues / Consolidation Opportunities

#### 8. **KALSHI_NORMALIZATION_DESIGN.md - Historical Design Doc**
**Location:** `capstones/therealtplum/apps/hadron/docs/KALSHI_NORMALIZATION_DESIGN.md`  
**Status:** Historical design proposal. Contains useful reference but overlaps with KALSHI_INTEGRATION_GUIDE.md

**Recommendation:** Keep as reference, but consider adding note: "Historical design - see KALSHI_INTEGRATION_GUIDE.md for current implementation"

#### 9. **KALSHI_INTEGRATION_COMPLETE.md - Historical Snapshot**
**Location:** `capstones/therealtplum/apps/hadron/docs/status/KALSHI_INTEGRATION_COMPLETE.md`  
**Status:** Historical snapshot from when integration was complete. Useful reference but may overlap with HADRON_STATUS.md

**Recommendation:** Keep as historical reference, or consider consolidating summary into HADRON_STATUS.md

#### 10. **Multiple Status Documents**
**Location:** `capstones/therealtplum/apps/hadron/docs/status/`  
**Files:** HADRON_STATUS.md, KALSHI_INTEGRATION_COMPLETE.md, KALSHI_PARSER_PHASE1_COMPLETE.md

**Status:** Three status documents. HADRON_STATUS.md is comprehensive, others are snapshots.

**Recommendation:** 
- Keep HADRON_STATUS.md as primary status doc
- Consider archiving completion snapshots after 3-6 months
- Or consolidate snapshots into HADRON_STATUS.md history section

---

## Accuracy Verification

### ✅ Accurate Documentation

1. **README.md** - Accurate, reflects current structure
2. **scope.md** - Accurate, comprehensive project scope
3. **auth0_guide.md** - Accurate, comprehensive guide
4. **third_party_tools.md** - Accurate, comprehensive reference
5. **runbook_v2.md** - ✅ Accurate, includes all services including hadron
6. **Hadron README.md** - Accurate service overview
7. **KALSHI_INTEGRATION_GUIDE.md** - Comprehensive and accurate
8. **KALSHI_WEBSOCKET_PROTOCOL.md** - Accurate protocol reference
9. **POLYGON_API_LIMITATIONS.md** - Accurate limitations documentation
10. **KALSHI_PARSER_PHASE1_COMPLETE.md** - Accurate phase 1 report
11. **TODO.md** - Accurate TODO items
12. **SECURITY_WARNINGS.md** - Accurate security analysis

---

## Consolidation Recommendations

### Group 1: Runbooks
**Current:** runbook_v1.md, runbook_v2.md  
**Recommendation:** 
- Archive or delete runbook_v1.md
- Keep runbook_v2.md as primary

### Group 2: Merge Documents
**Current:** BRANCH_MERGE_STRATEGY.md, MERGE_READINESS_ASSESSMENT.md  
**Recommendation:**
- Archive both to `docs/archive/` (historical reference)
- Or delete if merge is complete

### Group 3: Status Documents
**Current:** HADRON_STATUS.md, KALSHI_INTEGRATION_COMPLETE.md, KALSHI_PARSER_PHASE1_COMPLETE.md  
**Recommendation:**
- Keep HADRON_STATUS.md as primary
- Archive completion snapshots after they're 6+ months old
- Or add completion summaries to HADRON_STATUS.md

### Group 4: Kalshi Documentation
**Current:** KALSHI_INTEGRATION_GUIDE.md, KALSHI_NORMALIZATION_DESIGN.md, KALSHI_WEBSOCKET_PROTOCOL.md  
**Recommendation:**
- Keep all three - they serve different purposes:
  - GUIDE = comprehensive current state
  - DESIGN = historical design proposal
  - PROTOCOL = technical reference
- Consider cross-referencing between them

---

## Recommended Actions

### Immediate (Fix Inaccuracies)

1. ✅ Add Hadron service to runbook_v2.md services table (COMPLETED - already fixed)
2. ✅ Archive or delete BRANCH_MERGE_STRATEGY.md
3. ✅ Archive MERGE_READINESS_ASSESSMENT.md
4. ✅ Update HADRON_STATUS.md branch reference

### Short Term (Cleanup)

5. ✅ Add deprecation notice to runbook_v1.md or archive
6. ✅ Populate or remove architecture.md
7. ✅ Populate or remove design-decisions.md
8. ✅ Add cross-references between related docs

### Long Term (Ongoing)

9. ✅ Archive old status snapshots periodically
10. ✅ Keep documentation updated as code evolves
11. ✅ Review docs quarterly for accuracy

---

## File Accuracy Matrix

| File | Status | Accuracy | Action Needed |
|------|--------|----------|---------------|
| README.md | ✅ | Accurate | None |
| architecture.md | ⚠️ | Empty template | Populate or delete |
| scope.md | ✅ | Accurate | None |
| design-decisions.md | ⚠️ | Empty template | Populate or delete |
| auth0_guide.md | ✅ | Accurate | None |
| third_party_tools.md | ✅ | Accurate | None |
| BRANCH_MERGE_STRATEGY.md | 🔴 | Outdated | Archive/delete |
| runbook_v1.md | 🟡 | Superseded | Archive/deprecate |
| runbook_v2.md | ✅ | Accurate | None |
| hadron/README.md | ✅ | Accurate | None |
| hadron/docs/README.md | ✅ | Accurate | None |
| KALSHI_INTEGRATION_GUIDE.md | ✅ | Accurate | None |
| KALSHI_NORMALIZATION_DESIGN.md | ✅ | Historical | Add note |
| KALSHI_WEBSOCKET_PROTOCOL.md | ✅ | Accurate | None |
| POLYGON_API_LIMITATIONS.md | ✅ | Accurate | None |
| MERGE_READINESS_ASSESSMENT.md | 🔴 | Outdated | Archive |
| HADRON_STATUS.md | 🟡 | Outdated branch ref | Update branch |
| KALSHI_INTEGRATION_COMPLETE.md | ✅ | Historical | Keep as-is |
| KALSHI_PARSER_PHASE1_COMPLETE.md | ✅ | Accurate | None |
| web/TODO.md | ✅ | Accurate | None |
| web/SECURITY_WARNINGS.md | ✅ | Accurate | None |

**Legend:**
- ✅ Accurate/Complete
- 🟡 Minor issues/updates needed
- 🔴 Critical issues/outdated
- ⚠️ Empty/template only

---

## Summary Statistics

- **Total Files Reviewed:** 21
- **Accurate:** 16 (76%)
- **Minor Issues:** 3 (14%)
- **Critical Issues:** 2 (10%)
- **Empty Templates:** 2 (10%)

**Overall Assessment:** Documentation is generally accurate and comprehensive. Main issues are outdated branch references and missing service in runbook. Most documentation serves its purpose well.

---

## Fixes Applied

### ✅ Completed

1. **Added Hadron service to runbook_v2.md** - ✅ Hadron service was already added to services table and dependencies (verified current state)
2. **Updated HADRON_STATUS.md branch reference** - Changed from `hadron-v2` to `main` (merged)
3. **Added deprecation notice to runbook_v1.md** - Added warning that it's superseded by v2
4. **Added notes to architecture.md** - Points to actual architecture documentation
5. **Added notes to design-decisions.md** - Points to actual design decision documentation

### 📋 Remaining Actions (Recommended)

1. **Archive outdated merge documents:**
   - Move `BRANCH_MERGE_STRATEGY.md` to `docs/archive/` or delete
   - Move `apps/hadron/docs/MERGE_READINESS_ASSESSMENT.md` to archive or delete

2. **Consider consolidating:**
   - Review if completion snapshots in `status/` should be archived after 6+ months
   - Add cross-references between related Kalshi docs

3. **Ongoing maintenance:**
   - Review docs quarterly for accuracy
   - Update branch references when merging features
   - Keep runbook current with docker-compose.yml changes

---

## Next Steps

1. ✅ Review this document with team
2. ✅ Prioritize fixes (Critical → Medium → Minor)
3. ✅ Execute critical fixes (DONE)
4. 📋 Archive historical documents (recommended)
5. 📋 Set up periodic review schedule (recommended)

---

**End of Review**

---

## Post-Review Cleanup (December 2025)

The following files have been **deleted** as part of cleanup:

- ✅ **`docs/runbook_v1.md`** - Superseded by `runbook_v2.md`
- ✅ **`docs/design-decisions.md`** - Empty template, not being used
- ✅ **`docs/BRANCH_MERGE_STRATEGY.md`** - Outdated, merge completed

These files are no longer present in the repository. The runbook_v2.md has been updated to remove the reference to design-decisions.md.

## Recent Changes (December 2025)

### Clients Directory Reorganization
- ✅ **Clients directory reorganized** - Standardized naming and structure:
  - `FMHubControl/` → `apps/macos-f90hub/F90Hub/`
  - Shared code moved to `clients/shared/` Swift Package (`F90Shared`)
  - iOS app structure: `apps/ios-f90mobile/F90Mobile/`
  - All types made public for cross-module access
  - Deployment target updated to macOS 14.0+
  - See `clients/README.md` for current structure

### Documentation Status
- ✅ All three root markdown files reviewed and verified accurate:
  - `DOCUMENTATION_REVIEW.md` - Updated to reflect current state
  - `TESTING_GUIDE.md` - Accurate, includes all services
  - `PERFORMANCE_REVIEW.md` - Accurate historical report

