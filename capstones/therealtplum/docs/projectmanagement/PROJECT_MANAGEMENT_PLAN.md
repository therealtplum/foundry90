# Project Management Plan - Foundry90
**Date:** November 30, 2025  
**Status:** Active Management  
**Total Open Issues:** 79

## Executive Summary

### Current State
- ✅ **Issue #126 CLOSED** - Price change arrows implemented
- 📊 **79 open issues** across 10 epics
- 🎯 **Priority Focus:** API Hardening (#92) - 7 issues for production readiness
- 📈 **Active Work:** Kalshi integration (Phase 1 complete, Phase 2 in progress)

### Immediate Actions Needed
1. Mark high-priority issues as ready to start
2. Review older issues (#14-45) for current relevance
3. Update issue statuses based on actual work state
4. Prioritize sprint planning around API Hardening epic

---

## 📋 Issue Status Updates Required

### Issues to Mark as In-Progress

Based on codebase analysis, the following should be marked as actively being worked on:

**None currently - all appear to be in planning/backlog**

However, based on priority, we should START with:

1. **#124 - Typed config struct** (Foundation for API Hardening)
   - Status: Should be marked `in-progress` if starting
   - Priority: HIGH - Foundation for other hardening work

### Issues to Review/Close

Issues that may be already implemented or no longer relevant:

1. **Frontend Epic Issues (#93-99)** - Review against current UI state
   - #97 - "Add arrows + animations" - May overlap with #126 (which is now closed)
   - Need to check if others are already done

2. **News Epic Issues** - Check if news system is complete
   - #32 - `/instruments/{id}/news` endpoint - Need to verify if implemented

3. **Redis Epic Issues** - Check current Redis implementation
   - #23 - "Add connection pool" - May already be done

### Issues to Prioritize

**High Priority (Production Readiness):**
- API Hardening Epic (#92) - All 7 issues
  - #124: Typed config struct ⭐ START HERE
  - #118: Structured logging
  - #120: Request ID middleware
  - #119: Typed errors
  - #121: Split routes
  - #123: Rate limiting
  - #122: Integration tests

**Medium Priority (Feature Expansion):**
- Universe Epic (#91) - 6 issues for expanding coverage
- Frontend polish (#93-99) - UX improvements

**Lower Priority (Nice to Have):**
- ETL Orchestration (#89) - 7 issues
- Schema improvements (#83) - 7 issues
- Various other epics

---

## 🎯 Sprint Planning Recommendations

### Sprint 1: API Hardening Foundation (Week 1-2)
**Goal:** Establish foundation for production-ready API

1. **#124 - Typed config struct** (1 day)
   - Foundation for all other hardening work
   - Makes environment variable management cleaner

2. **#118 - Structured logging** (2-3 days)
   - Critical for production debugging
   - Should use JSON format with structured fields

3. **#120 - Request ID middleware** (1 day)
   - Works with structured logging
   - Essential for request tracing

**Expected Output:** API with proper config, logging, and request tracing

### Sprint 2: API Hardening Continuation (Week 3-4)
**Goal:** Complete core hardening features

4. **#119 - Typed errors** (2-3 days)
   - Better error handling and API responses
   - Replace anyhow with custom error types

5. **#121 - Split routes by domain** (2-3 days)
   - Code organization
   - Split into: instruments/, markets/, ops/, system/

6. **#123 - Rate limiting** (2-3 days)
   - Protect API from abuse
   - Use tower-ratelimit or similar

**Expected Output:** Well-organized, secure API with proper error handling

### Sprint 3: Testing & Universe Expansion (Week 5-6)
**Goal:** Validate API and expand coverage

7. **#122 - Integration tests** (5+ days)
   - Comprehensive test suite
   - Test all endpoints

8. **#117 - Update API filters** (1-2 days)
   - Add filtering by asset_class, region, etc.
   - Support expanded universe

9. **#116 - Update frontend filters** (2-3 days)
   - Build on API filters
   - UI for filtering instruments

**Expected Output:** Tested API with expanded universe support

---

## 📊 Epic Breakdown

### Epic: API Hardening (#92)
- **Status:** All issues open, ready to start
- **Priority:** HIGH - Production readiness
- **Issues:** 7 (all children of #92)
- **Recommended Start:** #124 (Typed config)

### Epic: Universe (#91)
- **Status:** Mixed - some partially done
- **Priority:** MEDIUM - Feature expansion
- **Issues:** 6 (all children of #91)
- **Key Issues:** #115 (Kalshi - in progress), #117 (API filters)

### Epic: Frontend (#88)
- **Status:** Some may be done (e.g., #126 closed)
- **Priority:** MEDIUM - UX improvements
- **Issues:** 8 (all children of #88)
- **Action:** Review #97 vs #126 overlap

### Epic: ETL Orchestration (#89)
- **Status:** All open
- **Priority:** MEDIUM - Operational improvements
- **Issues:** 7 (all children of #89)

### Epic: Schema (#83)
- **Status:** All open
- **Priority:** MEDIUM - Database improvements
- **Issues:** 7 (all children of #83)

### Other Epics
- News (#85): 7 issues
- Redis (#86): 7 issues
- Market Data (#87): 9 issues
- FMHub (#84): 7 issues
- Insights (#90): 7 issues

---

## 🔄 Status Update Actions

### Immediate Actions (Next Steps)

1. **Review Frontend Issues (#93-99)**
   - Check which are already implemented
   - Verify #97 vs #126 overlap
   - Close any duplicates

2. **Start API Hardening**
   - Mark #124 as `in-progress` when ready to start
   - Update project board

3. **Audit Older Issues (#14-45)**
   - Review for current relevance
   - Close if superseded
   - Update if scope changed

4. **Update Kalshi Status**
   - Issue #115 mentions "prediction markets module"
   - Kalshi is already integrated (Phase 1 complete)
   - May need to update issue description or close if done

---

## 📈 Metrics & Progress Tracking

### Current Metrics
- **Total Issues:** 79 open
- **Issues Closed Today:** 1 (#126)
- **Epics Active:** 10
- **Issues in Progress:** 0 (none marked)

### Target Metrics
- **Sprint 1 Goal:** Complete 3 API Hardening issues (#124, #118, #120)
- **Sprint 2 Goal:** Complete 3 more API Hardening issues (#119, #121, #123)
- **Month 1 Goal:** Complete API Hardening epic + start Universe expansion

---

## 🎯 Next Actions

1. ✅ Close Issue #126 (COMPLETED)
2. ⏳ Review and update Frontend issues (#93-99)
3. ⏳ Mark #124 as in-progress when starting API Hardening
4. ⏳ Audit older issues (#14-45) for relevance
5. ⏳ Update Kalshi-related issues (#115) with current status
6. ⏳ Create detailed sprint plan for API Hardening epic

---

## 📝 Notes

- All parent/child relationships preserved for kanban board
- Epic structure drives organization
- Priority is production readiness first, then feature expansion
- Kalshi integration work continues in parallel (Phase 2)

---

**Last Updated:** November 30, 2025  
**Next Review:** After Sprint 1 completion

