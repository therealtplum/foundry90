# Hadron Documentation Index

This directory contains documentation for the Hadron Real-Time Intelligence System. Documents are organized by type: **reference documentation** (static/semi-static) and **status updates** (progress tracking).

## 📁 Directory Structure

```
docs/
├── README.md                          # This file
├── status/                            # Status & progress updates
│   ├── HADRON_STATUS.md              # Overall system status & roadmap
│   ├── KALSHI_INTEGRATION_COMPLETE.md # Kalshi integration completion snapshot
│   ├── KALSHI_NORMALIZATION_STATUS.md # Kalshi normalization implementation status
│   ├── KALSHI_PARSER_PHASE1_COMPLETE.md # Phase 1 parser completion report
│   └── archive/                      # Archived documents (historical reference)
│       ├── KALSHI_NORMALIZATION_DESIGN.md # Original normalization design proposal
│       └── MERGE_READINESS_ASSESSMENT.md # Hadron-v2 merge assessment (completed)
├── KALSHI_INTEGRATION_GUIDE.md        # Comprehensive Kalshi integration reference
├── KALSHI_WEBSOCKET_PROTOCOL.md       # Kalshi WebSocket protocol reference
└── POLYGON_API_LIMITATIONS.md         # Polygon API plan details & limitations
```

---

## 📚 Reference Documentation (Static/Semi-Static)

These documents contain reference information that changes infrequently. Use these for understanding how things work.

### Protocol & API References
- **`KALSHI_WEBSOCKET_PROTOCOL.md`** - Kalshi WebSocket protocol reference
  - Authentication (RSA-PSS signing)
  - Message formats
  - Subscription patterns
  - Error handling

- **`POLYGON_API_LIMITATIONS.md`** - Polygon API plan details
  - Current subscription status
  - Data limitations (delayed, REST-only endpoints)
  - Implementation notes

### Architecture & Design
- **`status/archive/KALSHI_NORMALIZATION_DESIGN.md`** - Original design proposal (archived, historical reference)
  - Two-path approach (fast-path/slow-path)
  - Database schema considerations
  - Ticker parser design
  - See `status/KALSHI_NORMALIZATION_STATUS.md` for current implementation status

### Comprehensive Guides
- **`KALSHI_INTEGRATION_GUIDE.md`** - **PRIMARY KALSHI REFERENCE**
  - What we've learned
  - Best practices
  - Current state
  - To-do items by phase
  - Quick start guide

---

## 📊 Status & Progress Updates (`status/`)

These documents track current status and progress. Updated regularly as features are completed.

### Overall System Status
- **`status/HADRON_STATUS.md`** - **PRIMARY STATUS DOCUMENT**
  - Overall Hadron system status
  - Implementation progress
  - Roadmap
  - Covers: Core architecture, Polygon integration, reference data, market status

### Venue-Specific Status
- **`status/KALSHI_INTEGRATION_COMPLETE.md`** - Kalshi integration completion summary
  - Historical snapshot of what was implemented
  - Status: Integration complete, operational
  - Use: Historical reference

- **`status/KALSHI_NORMALIZATION_STATUS.md`** - Kalshi normalization implementation status
  - Phase-by-phase implementation tracking
  - Current progress (Phase 1 complete, Phase 2 in progress)
  - Roadmap and next steps

- **`status/KALSHI_PARSER_PHASE1_COMPLETE.md`** - Phase 1 ticker parser completion report
  - Parser capabilities
  - Test results
  - Known limitations
  - Next steps

---

## 🗺️ Document Mapping by Service/Venue

### Polygon Integration
- **Reference**: `POLYGON_API_LIMITATIONS.md`
- **Status**: `status/HADRON_STATUS.md` (includes Polygon section)

### Kalshi Integration
- **Primary Reference**: `KALSHI_INTEGRATION_GUIDE.md` - **START HERE**
- **Protocol Reference**: `KALSHI_WEBSOCKET_PROTOCOL.md`
- **Implementation Status**: `status/KALSHI_NORMALIZATION_STATUS.md` - **CURRENT STATUS**
- **Design Reference**: `status/archive/KALSHI_NORMALIZATION_DESIGN.md` (historical)
- **Status**: 
  - `status/HADRON_STATUS.md` (overall system)
  - `status/KALSHI_NORMALIZATION_STATUS.md` (normalization progress)
  - `status/KALSHI_INTEGRATION_COMPLETE.md` (historical snapshot)
  - `status/KALSHI_PARSER_PHASE1_COMPLETE.md` (phase 1 completion)

### General/Cross-Venue
- **Status**: `status/HADRON_STATUS.md`

---

## 📖 Quick Reference Guide

### For New Developers
1. **Start with**: `status/HADRON_STATUS.md` - Get overall system understanding
2. **Then read**: `KALSHI_INTEGRATION_GUIDE.md` - Understand Kalshi integration
3. **Reference**: `KALSHI_WEBSOCKET_PROTOCOL.md` - When working with Kalshi WebSocket

### For Operations
1. **Monitor status**: `status/HADRON_STATUS.md` - Current system status
2. **Troubleshoot**: `KALSHI_WEBSOCKET_PROTOCOL.md` - Protocol details and common issues
3. **Understand limitations**: `POLYGON_API_LIMITATIONS.md` - API constraints

### For Planning
1. **Current state**: `status/HADRON_STATUS.md` - What's implemented
2. **Kalshi roadmap**: `KALSHI_INTEGRATION_GUIDE.md` - Phase 2/3/4 plans
3. **Normalization status**: `status/KALSHI_NORMALIZATION_STATUS.md` - Implementation progress
4. **Design reference**: `status/archive/KALSHI_NORMALIZATION_DESIGN.md` - Original design (archived)

---

## 🔄 Document Update Frequency

### High Frequency (Updated Regularly)
- **`status/HADRON_STATUS.md`** - Updated as features are completed
- **`KALSHI_INTEGRATION_GUIDE.md`** - Updated as new learnings are added

### Medium Frequency (Updated Periodically)
- **`status/KALSHI_PARSER_PHASE1_COMPLETE.md`** - Updated when parser capabilities expand

### Low Frequency (Rarely Updated)
- **`KALSHI_WEBSOCKET_PROTOCOL.md`** - Only updated if protocol changes
- **`POLYGON_API_LIMITATIONS.md`** - Only updated if plan changes
- **`status/archive/KALSHI_NORMALIZATION_DESIGN.md`** - Historical reference, archived
- **`status/KALSHI_INTEGRATION_COMPLETE.md`** - Historical snapshot, not updated

---

## 📝 Document Naming Convention

### Reference Documentation (Root `docs/`)
- **`*_PROTOCOL.md`** - Protocol/API reference documentation
- **`*_DESIGN.md`** - Design proposals (reference)
- **`*_GUIDE.md`** - Comprehensive guides (living documents)
- **`*_LIMITATIONS.md`** - Service-specific limitations/constraints

### Status Documents (`docs/status/`)
- **`HADRON_STATUS.md`** - Overall system status
- **`*_STATUS.md`** - Implementation status tracking (active progress)
- **`*_COMPLETE.md`** - Completion summaries (historical snapshots)
- **`*_PHASE*_COMPLETE.md`** - Phase completion reports
- **`archive/`** - Archived documents (historical reference only)

---

## 🎯 Primary Documents by Use Case

### Understanding Current State
- **`status/HADRON_STATUS.md`** - Overall system
- **`KALSHI_INTEGRATION_GUIDE.md`** - Kalshi integration

### Working with Kalshi
- **`KALSHI_INTEGRATION_GUIDE.md`** - Best practices and current state
- **`KALSHI_WEBSOCKET_PROTOCOL.md`** - Protocol details

### Working with Polygon
- **`status/HADRON_STATUS.md`** - Overall status
- **`POLYGON_API_LIMITATIONS.md`** - API constraints

### Planning New Features
- **`status/HADRON_STATUS.md`** - Roadmap
- **`KALSHI_INTEGRATION_GUIDE.md`** - Phase 2/3/4 plans
- **`KALSHI_NORMALIZATION_DESIGN.md`** - Design reference

---

**Last Updated:** December 2025
