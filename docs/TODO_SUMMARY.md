# TODO Summary - UX Improvements

**Generated:** 2025-11-21
**Based on:** [UX Review](./UX_REVIEW.md) | [UX Manifesto v2.0](https://github.com/larsbx/code_review_manifestos/blob/claude%2Fgather-manifestos-01K8uBEmrzw9EYdR7hW3nuUG/user_experience%2FUX_MANIFESTO.md)

This document lists all TODOs added to the codebase for UX improvements, organized by priority and file location.

---

## Critical Priority (Must Fix Before Production)

### 1. Add Reset Confirmation Dialog
**Files:** `src/ui.zig:15-18, 73-78`
**Effort:** 2 hours
**Impact:** Prevents catastrophic data loss from accidental keypress

**Current Issue:**
```zig
} else if (key.matches('r', .{})) {
    try self.reset(g);  // NO CONFIRMATION!
}
```

**Implementation Steps:**
1. Add `confirm_reset` mode to `UIMode` enum
2. Change reset handler to set mode instead of calling reset
3. Add confirmation handler in help mode waiting for 'y' or 'n'
4. Display "Reset all data? [y/n]" message

**Locations:**
- `src/ui.zig:15` - Add enum variant
- `src/ui.zig:73` - Update key handler
- Add new render function for confirmation dialog

---

### 2. Implement Async LLM Calls
**Files:** `src/ui.zig:173-182`, `src/analysis_service.zig:8-15`
**Effort:** 8 hours
**Impact:** Eliminates 2-30s UI freezes, dramatically improves responsiveness

**Current Issue:**
```zig
self.mode = .analyzing;
try self.analysis.analyzeNewIdea(...);  // BLOCKS FOR SECONDS
self.mode = .viewing_graph;
```

**Implementation Steps:**
1. Add `analysis_task: ?std.Thread` field to `UIState`
2. Create async wrapper function for analysis
3. Spawn background thread in `analyzeNewIdea()`
4. Poll thread completion in main event loop
5. Add atomic cancellation flag
6. Update `renderAnalyzing()` with progress indicator

**Locations:**
- `src/ui.zig:32` - Add thread field to UIState
- `src/ui.zig:173-182` - Make analysis async
- `src/analysis_service.zig:8-15` - Add cancellation support
- `src/ui.zig:338-346` - Update progress rendering

---

### 3. Add Cancel During Analysis
**Files:** `src/ui.zig:123-128`
**Effort:** 4 hours
**Impact:** Gives users control over long operations

**Current Issue:**
```zig
.analyzing => {
    // Wait for analysis to complete
},
```

**Implementation Steps:**
1. Add cancellation flag check in analysis loop
2. Add Escape key handler in analyzing mode
3. Implement thread interruption mechanism
4. Clean up partial results on cancellation

**Locations:**
- `src/ui.zig:123-128` - Add key handler
- `src/analysis_service.zig` - Add cancellation checks
- `src/llm.zig` - Make API calls interruptible

---

### 4. Add Animated Progress Spinner
**Files:** `src/ui.zig:338-346`
**Effort:** 3 hours
**Impact:** Provides visual feedback that work is happening

**Implementation:**
```zig
const spinners = [_][]const u8{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" };
const msg = try std.fmt.allocPrint(allocator,
    "{s} Analyzing... {d}s elapsed",
    .{spinners[frame % spinners.len], elapsed_seconds});
```

**Locations:**
- `src/ui.zig:338-346` - Update `renderAnalyzing()`
- `src/ui.zig:32` - Add frame counter to UIState
- `src/main.zig` - Pass frame counter from event loop

---

## High Priority (Significant UX Impact)

### 5. Implement Undo Stack
**Files:** `src/ui.zig:33-36`, new file `src/undo_stack.zig`
**Effort:** 12 hours
**Impact:** Enables experimentation without fear

**Implementation Steps:**
1. Create `src/undo_stack.zig` module
2. Define undo operation types (add idea, reset, etc.)
3. Store graph snapshots before mutations
4. Add Ctrl+Z key handler
5. Add undo/redo to help screen
6. Limit stack to last N operations (e.g., 20)

**Locations:**
- `src/undo_stack.zig` - New file
- `src/ui.zig:33-36` - Add undo_stack field
- `src/ui.zig:handleKey()` - Add Ctrl+Z handler
- `src/graph.zig` - Add clone method for snapshots

---

### 6. Add Vertex-Focused Navigation
**Files:** `src/ui.zig:26-29, 132-143`
**Effort:** 6 hours
**Impact:** Makes graph exploration more intuitive

**Current Issue:**
```zig
// Can only navigate edges, not vertices
} else if (key.matches(vaxis.Key.up, .{})) {
    if (self.selected_edge) |*idx| { ... }
```

**Implementation Steps:**
1. Add `selected_vertex: ?usize` field to UIState
2. Add 'v' key to toggle between edge/vertex selection mode
3. Use left/right arrow keys for vertex navigation
4. Highlight connected edges when vertex selected
5. Show vertex details panel (idea text, connection count)

**Locations:**
- `src/ui.zig:26-29` - Add selected_vertex field
- `src/ui.zig:132-143` - Update navigation logic
- `src/ui.zig:renderGraph()` - Add vertex highlighting

---

### 7. Add Privacy Notice
**Files:** `src/ui.zig:227-232`
**Effort:** 2 hours
**Impact:** Transparency about data handling

**Implementation Steps:**
1. Add `first_launch: bool` flag to UIState (default true)
2. Display privacy notice on first launch
3. Explain that ideas are sent to configured LLM API
4. Add "Press any key to continue" prompt
5. Set first_launch = false after acknowledgment
6. Consider persistent config file for flag

**Locations:**
- `src/ui.zig:227-232` - Add notice to renderHelp()
- `src/ui.zig` - Add first_launch field
- Consider: `~/.config/tui-story/config` for persistence

---

## Medium Priority (Enhancements)

### 8. Add ASCII Fallback Mode
**Files:** `src/graph.zig:42-63`
**Effort:** 3 hours
**Impact:** Broader terminal compatibility

**Implementation:**
```zig
pub fn getSymbol(self: RelationType, ascii_mode: bool) []const u8 {
    if (ascii_mode) {
        return switch (self) {
            .contradictory => "!=",
            .implicative => "->",
            // ... etc
        };
    }
    // Current unicode symbols
}
```

**Locations:**
- `src/graph.zig:42-63` - Update getSymbol()
- `src/ui.zig` - Add ascii_mode config option
- Environment variable: `TUI_ASCII_MODE=1`

---

### 9. Add Search and Filtering
**Files:** `src/ui.zig:137-143`, new file `src/search.zig`
**Effort:** 8 hours
**Impact:** Essential for large graphs (50+ ideas)

**Implementation Steps:**
1. Add search mode to UIMode enum
2. Create search input handler
3. Implement fuzzy text matching
4. Filter vertices/edges by search term
5. Add relationship type filters
6. Show filtered results count

**Locations:**
- `src/search.zig` - New file for search logic
- `src/ui.zig:137-143` - Add '/' key handler
- `src/ui.zig` - Add search_mode and search rendering

---

### 10. Add Contextual Help
**Files:** `src/ui.zig:141-143` (all modes)
**Effort:** 4 hours
**Impact:** Reduces learning curve

**Implementation Steps:**
1. Add '?' key handler in all modes
2. Create help text for each mode
3. Display context-specific shortcuts
4. Add help overlay without mode change
5. Press '?' again to dismiss

**Locations:**
- `src/ui.zig` - Add '?' handler to each mode
- `src/ui.zig` - Create renderHelpOverlay() function

---

## Low Priority / Quick Wins

### 11. Add Ellipsis to Truncated Text
**Files:** `src/ui.zig:406-413`
**Effort:** 30 minutes
**Impact:** Visual clarity

**Current:**
```zig
const display_text = if (vertex.content.len > max_len)
    vertex.content[0..max_len]  // Abrupt cut
```

**Needed:**
```zig
const display_text = if (vertex.content.len > max_len)
    try std.fmt.allocPrint(allocator, "{s}...", .{vertex.content[0..max_len-3]})
```

**Locations:**
- `src/ui.zig:406-413` - Update text truncation

---

### 12. Improve Error Messages
**Files:** `src/validation.zig:4-9`
**Effort:** 2 hours
**Impact:** More actionable feedback

**Current:** "Error: Input too long (max 1000 chars)"
**Needed:** "Error: Input is 1247 chars, max is 1000. Please shorten by 247 chars."

**Implementation:**
1. Change ValidationError to include context
2. Pass actual length to error
3. Calculate overage
4. Update error display in ui.zig

**Locations:**
- `src/validation.zig:4-9` - Update error type
- `src/validation.zig:validateIdea()` - Include details
- `src/ui.zig:69-77` - Display detailed errors

---

## Implementation Order (Recommended)

### Sprint 1 (Critical Fixes)
**Total: 14.5 hours**

Week 1:
1. ✅ Add reset confirmation (2h) - Easy, high impact
2. ✅ Add ellipsis to truncated text (0.5h) - Quick win
3. ✅ Start async LLM implementation (8h)

Week 2:
4. ✅ Complete async + spinner (3h)
5. ✅ Add cancel capability (4h)

**Outcome:** Eliminates all CRITICAL data loss and responsiveness issues

---

### Sprint 2 (High Priority)
**Total: 24 hours**

Week 3:
6. ✅ Privacy notice (2h)
7. ✅ Animated spinner polish (included above)
8. ✅ Start vertex navigation (6h)

Week 4:
9. ✅ Complete vertex navigation
10. ✅ Begin undo stack (12h)

**Outcome:** Forgiveness and better navigation

---

### Sprint 3 (Medium Priority)
**Total: 17 hours**

Week 5:
11. ✅ Complete undo stack
12. ✅ ASCII fallback mode (3h)
13. ✅ Contextual help (4h)

Week 6:
14. ✅ Search and filtering (8h)
15. ✅ Better error messages (2h)

**Outcome:** Polish and accessibility improvements

---

## Files Modified Summary

| File | TODOs Added | Priority | Total Effort |
|------|-------------|----------|--------------|
| `src/ui.zig` | 11 | 3 CRITICAL, 3 HIGH, 3 MEDIUM, 2 LOW | 35+ hours |
| `src/analysis_service.zig` | 1 | CRITICAL | Part of async work |
| `src/graph.zig` | 1 | MEDIUM | 3 hours |
| `src/validation.zig` | 1 | LOW | 2 hours |
| **New: `src/undo_stack.zig`** | - | HIGH | 12 hours |
| **New: `src/search.zig`** | - | MEDIUM | 8 hours |

**Total TODOs:** 14 across 4 existing files, 2 new files needed
**Total Estimated Effort:** 60+ hours (3-4 sprints)

---

## Tracking Progress

### How to Find TODOs

Search for TODO tags in code:
```bash
# All UX TODOs
grep -r "TODO(UX-" src/

# By priority
grep -r "TODO(UX-CRITICAL)" src/
grep -r "TODO(UX-HIGH)" src/
grep -r "TODO(UX-MEDIUM)" src/
grep -r "TODO(UX-QUICK-WIN)" src/
```

### TODO Format

All TODOs follow this format:
```zig
// TODO(UX-PRIORITY): Brief description
// See: docs/UX_REVIEW.md - Principle #N (Principle Name)
// Current: What's wrong now
// Needed: What needs to change
// Effort: X hours | Priority: LEVEL
// Implementation: Step-by-step guide
```

### GitHub Issues

Consider creating GitHub issues for each TODO category:
- Issue #XX: [CRITICAL] UX Improvements - Data Safety
- Issue #XX: [CRITICAL] UX Improvements - Responsiveness
- Issue #XX: [HIGH] UX Improvements - Forgiveness & Navigation
- Issue #XX: [MEDIUM] UX Improvements - Accessibility & Search

---

## Testing Strategy

### After Each TODO Implementation

1. **Unit Tests**
   - Add tests to appropriate test file
   - Verify memory safety with leak detection
   - Test edge cases

2. **Integration Tests**
   - Add workflow tests to `tests/integration/`
   - Test with mock LLM data
   - Test with real API (optional)

3. **Manual Testing**
   - Test in various terminals (xterm, gnome-terminal, iTerm2, etc.)
   - Test with different terminal sizes
   - Test keyboard shortcuts
   - Test error conditions

4. **Accessibility Testing**
   - Test keyboard-only navigation
   - Verify color contrast
   - Test ASCII mode (if implemented)

### Test Coverage Goals

- Unit test coverage: >80%
- Integration test coverage: All critical workflows
- Manual testing: All UX scenarios in docs/UX_REVIEW.md

---

## Completion Criteria

### Critical Priority (Required for Production)
- [ ] Reset confirmation dialog working
- [ ] LLM calls are async and non-blocking
- [ ] Analysis can be cancelled with Escape
- [ ] Progress spinner animates during analysis
- [ ] No UI freezes >100ms

### High Priority (Required for v1.0)
- [ ] Undo/redo functionality working
- [ ] Vertex-focused navigation available
- [ ] Privacy notice displayed on first launch
- [ ] User testing completed (5+ users)

### Medium Priority (Required for v1.1)
- [ ] ASCII mode available
- [ ] Search and filtering working
- [ ] Contextual help in all modes
- [ ] Export/import functionality

### Low Priority (Nice to Have)
- [ ] Ellipsis on truncated text
- [ ] Detailed error messages
- [ ] Progressive graph detail levels
- [ ] Batch import

---

## Resources

- **UX Review:** [docs/UX_REVIEW.md](./UX_REVIEW.md)
- **Quick Reference:** [docs/UX_IMPROVEMENTS_SUMMARY.md](./UX_IMPROVEMENTS_SUMMARY.md)
- **UX Manifesto:** [GitHub](https://github.com/larsbx/code_review_manifestos/blob/claude%2Fgather-manifestos-01K8uBEmrzw9EYdR7hW3nuUG/user_experience%2FUX_MANIFESTO.md)
- **Architecture:** [docs/architecture/](./architecture/)

---

**Last Updated:** 2025-11-21
**Next Review:** After Sprint 1 completion
**Questions:** Search codebase for `TODO(UX-` or check GitHub issues
