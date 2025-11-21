const std = @import("std");

/// Input validation errors
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

// Unit tests
test "validateVertexContent rejects empty content" {
    const result = validateVertexContent("");
    try std.testing.expectError(ValidationError.EmptyContent, result);
}

test "validateVertexContent accepts valid UTF-8" {
    try validateVertexContent("hello");
    try validateVertexContent("hello world");
    try validateVertexContent("émojis: 🎉🚀");
    try validateVertexContent("中文文本");
    try validateVertexContent(" "); // whitespace is valid content
}

test "validateVertexContent rejects invalid UTF-8" {
    // Invalid UTF-8 sequence: 0xFF is never valid in UTF-8
    const invalid_utf8 = &[_]u8{ 0xFF, 0xFE };
    const result = validateVertexContent(invalid_utf8);
    try std.testing.expectError(ValidationError.InvalidUtf8, result);
}
