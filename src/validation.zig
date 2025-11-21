const std = @import("std");

/// Input validation errors
// TODO(UX-QUICK-WIN): Make error messages more actionable with specific details
// See: docs/UX_REVIEW.md - Principle #12 (Error Prevention Over Error Handling)
// Current: Generic error messages
// Needed: Include actual length, characters over limit, etc.
// Effort: 2 hours | Priority: LOW (Quick Win)
// Example: Instead of "Input too long", show "Input is 1247 chars, max is 1000. Please shorten by 247 chars."
pub const ValidationError = error{
    EmptyInput,
    InputTooLong,
    InvalidUtf8,
    InvalidGroup,
    EmptyContent,
};

/// Maximum length for user-entered ideas (prevents memory exhaustion)
pub const MAX_IDEA_LENGTH = 1000;

/// Validates and sanitizes user input for ideas
pub fn validateIdea(input: []const u8) ValidationError!void {
    if (input.len == 0) {
        return ValidationError.EmptyInput;
    }

    if (input.len > MAX_IDEA_LENGTH) {
        return ValidationError.InputTooLong;
    }

    if (!std.unicode.utf8ValidateSlice(input)) {
        return ValidationError.InvalidUtf8;
    }
}

/// Validates group number (must be 0 or 1)
pub fn validateGroup(group: usize) ValidationError!void {
    if (group > 1) {
        return ValidationError.InvalidGroup;
    }
}

/// Validates vertex content for graph operations
// TODO: Add unit tests for validateVertexContent()
pub fn validateVertexContent(content: []const u8) ValidationError!void {
    if (content.len == 0) {
        return ValidationError.EmptyContent;
    }

    if (!std.unicode.utf8ValidateSlice(content)) {
        return ValidationError.InvalidUtf8;
    }
}

/// Sanitizes input by trimming whitespace
pub fn sanitizeInput(input: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const trimmed = std.mem.trim(u8, input, &std.ascii.whitespace);
    return allocator.dupe(u8, trimmed);
}
