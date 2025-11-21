const std = @import("std");
const testing = std.testing;
const validation = @import("validation");

// ============================================================================
// validateVertexContent Tests
// ============================================================================

test "validateVertexContent rejects empty content" {
    const result = validation.validateVertexContent("");
    try testing.expectError(validation.ValidationError.EmptyContent, result);
}

test "validateVertexContent accepts valid UTF-8" {
    try validation.validateVertexContent("hello");
    try validation.validateVertexContent("hello world");
    try validation.validateVertexContent("émojis: 🎉🚀");
    try validation.validateVertexContent("中文文本");
    try validation.validateVertexContent(" "); // whitespace is valid content
}

test "validateVertexContent rejects invalid UTF-8" {
    // Invalid UTF-8 sequence: 0xFF is never valid in UTF-8
    const invalid_utf8 = &[_]u8{ 0xFF, 0xFE };
    const result = validation.validateVertexContent(invalid_utf8);
    try testing.expectError(validation.ValidationError.InvalidUtf8, result);
}
