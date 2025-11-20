const std = @import("std");
const graph = @import("graph");

const log = std.log.scoped(.llm);

/// Configuration for API resilience
const APIConfig = struct {
    max_retries: u8 = 3,
    timeout_ms: u64 = 30_000, // 30 seconds
    initial_backoff_ms: u64 = 1_000, // 1 second
};

pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    api_key: ?[]const u8,
    api_endpoint: []const u8,
    http_client: std.http.Client,
    config: APIConfig,

    pub fn init(allocator: std.mem.Allocator) LLMClient {
        const api_key = std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch null;

        if (api_key) |_| {
            log.info("LLM client initialized with API key", .{});
        } else {
            log.warn("LLM client initialized without API key - using mock data", .{});
        }

        return .{
            .allocator = allocator,
            .api_key = api_key,
            .api_endpoint = "https://api.anthropic.com/v1/messages",
            .http_client = std.http.Client{ .allocator = allocator },
            .config = .{},
        };
    }

    pub fn deinit(self: *LLMClient) void {
        if (self.api_key) |key| {
            self.allocator.free(key);
        }
        self.http_client.deinit();
    }

    pub fn analyzeRelationships(
        self: *LLMClient,
        group1: []const []const u8,
        group2: []const []const u8,
    ) ![]Relationship {
        log.info("Analyzing relationships between {} and {} ideas", .{ group1.len, group2.len });

        // For now, return mock data if no API key is set
        // In production, this would make real API calls
        if (self.api_key == null) {
            log.debug("Using mock relationship generation", .{});
            return try self.getMockRelationships(group1, group2);
        }

        log.debug("Building LLM prompt", .{});
        const prompt = try self.buildPrompt(group1, group2);
        defer self.allocator.free(prompt);

        log.info("Calling LLM API", .{});
        const response = try self.callAPI(prompt);
        defer self.allocator.free(response);

        log.debug("Parsing LLM response", .{});
        return try self.parseResponse(response);
    }

    pub fn buildPrompt(self: *LLMClient, group1: []const []const u8, group2: []const []const u8) ![]const u8 {
        var prompt = std.ArrayList(u8).init(self.allocator);
        defer prompt.deinit();

        const writer = prompt.writer();

        try writer.writeAll("Analyze the semantic relationships between these two groups of ideas:\n\n");
        try writer.writeAll("Group A:\n");
        for (group1) |idea| {
            try writer.print("- {s}\n", .{idea});
        }

        try writer.writeAll("\nGroup B:\n");
        for (group2) |idea| {
            try writer.print("- {s}\n", .{idea});
        }

        try writer.writeAll("\nFor each possible relationship between ideas in Group A and Group B, identify:\n");
        try writer.writeAll("1. The relationship type (CONTRADICTORY, IMPLICATIVE, HIERARCHICAL, EVOLUTIONARY, ANALOGOUS, SYNONYMOUS, ANTONYMOUS, PART_WHOLE, or CAUSAL)\n");
        try writer.writeAll("2. The certainty score (0.0 to 1.0)\n");
        try writer.writeAll("3. A brief explanation\n\n");
        try writer.writeAll("Format your response as JSON:\n");
        try writer.writeAll("[\n");
        try writer.writeAll("  {\"from\": \"idea from A\", \"to\": \"idea from B\", \"type\": \"RELATIONSHIP_TYPE\", \"certainty\": 0.9, \"description\": \"explanation\"},\n");
        try writer.writeAll("  ...\n");
        try writer.writeAll("]\n");

        return prompt.toOwnedSlice();
    }

    fn callAPI(self: *LLMClient, prompt: []const u8) ![]const u8 {
        var retries: u8 = 0;
        var backoff_ms = self.config.initial_backoff_ms;

        while (retries < self.config.max_retries) : (retries += 1) {
            log.debug("API call attempt {} of {}", .{ retries + 1, self.config.max_retries });

            // TODO: Implement actual API call with timeout
            // For now, simulate potential transient failures
            const result = self.makeAPIRequest(prompt) catch |err| {
                log.warn("API call failed (attempt {}): {}", .{ retries + 1, err });

                if (retries < self.config.max_retries - 1) {
                    log.info("Retrying after {}ms backoff", .{backoff_ms});
                    std.time.sleep(backoff_ms * std.time.ns_per_ms);
                    backoff_ms *= 2; // Exponential backoff
                    continue;
                }

                log.err("Max retries exceeded, failing request", .{});
                return err;
            };

            log.info("API call successful on attempt {}", .{retries + 1});
            return result;
        }

        return error.MaxRetriesExceeded;
    }

    fn makeAPIRequest(self: *LLMClient, prompt: []const u8) ![]const u8 {
        _ = prompt;

        // TODO: Implement actual HTTP request with timeout
        // This would include:
        // 1. Creating HTTP request with headers (API key, content-type)
        // 2. Setting timeout on the request
        // 3. Sending request and reading response
        // 4. Handling various HTTP status codes
        //
        // Example structure:
        // var req = try self.http_client.open(.POST, self.api_endpoint, .{
        //     .server_header_buffer = &server_header_buffer,
        // });
        // defer req.deinit();
        // req.transfer_encoding = .chunked;
        //
        // Set timeout using a timer or similar mechanism
        // const timeout_timer = try std.time.Timer.start();
        //
        // Write request body and read response with timeout checking

        // For now, return empty JSON array
        return try self.allocator.dupe(u8, "[]");
    }

    fn parseResponse(self: *LLMClient, response: []const u8) ![]Relationship {
        // Parse JSON response from LLM API
        const parsed = std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response,
            .{},
        ) catch |err| {
            log.err("Failed to parse JSON response: {}", .{err});
            return error.InvalidJSON;
        };
        defer parsed.deinit();

        const root = parsed.value;
        if (root != .array) {
            log.err("Expected JSON array, got: {}", .{root});
            return error.InvalidJSONFormat;
        }

        var relationships = std.ArrayList(Relationship).init(self.allocator);
        errdefer {
            for (relationships.items) |*rel| {
                rel.deinit(self.allocator);
            }
            relationships.deinit();
        }

        for (root.array.items) |item| {
            if (item != .object) {
                log.warn("Skipping non-object item in array", .{});
                continue;
            }

            const obj = item.object;

            // Extract required fields
            const from = obj.get("from") orelse {
                log.warn("Missing 'from' field in relationship", .{});
                continue;
            };
            const to = obj.get("to") orelse {
                log.warn("Missing 'to' field in relationship", .{});
                continue;
            };
            const rel_type = obj.get("type") orelse {
                log.warn("Missing 'type' field in relationship", .{});
                continue;
            };
            const certainty = obj.get("certainty") orelse {
                log.warn("Missing 'certainty' field in relationship", .{});
                continue;
            };
            const desc = obj.get("description") orelse {
                log.warn("Missing 'description' field in relationship", .{});
                continue;
            };

            // Validate field types
            if (from != .string or to != .string or rel_type != .string or desc != .string) {
                log.warn("Invalid field types in relationship object", .{});
                continue;
            }
            if (certainty != .number_string and certainty != .float and certainty != .integer) {
                log.warn("Invalid certainty type", .{});
                continue;
            }

            // Convert relationship type string to enum
            const relation_type = graph.RelationType.fromString(rel_type.string) catch {
                log.warn("Unknown relationship type: {s}", .{rel_type.string});
                continue;
            };

            // Extract certainty value
            const certainty_value: f32 = switch (certainty) {
                .float => |f| @as(f32, @floatCast(f)),
                .integer => |i| @as(f32, @floatFromInt(i)),
                .number_string => |s| std.fmt.parseFloat(f32, s) catch {
                    log.warn("Invalid certainty number string: {s}", .{s});
                    continue;
                },
                else => unreachable,
            };

            // Create relationship
            const relationship = Relationship{
                .from_idea = try self.allocator.dupe(u8, from.string),
                .to_idea = try self.allocator.dupe(u8, to.string),
                .relation_type = relation_type,
                .certainty = certainty_value,
                .description = try self.allocator.dupe(u8, desc.string),
            };

            try relationships.append(relationship);
        }

        log.info("Parsed {} relationships from response", .{relationships.items.len});
        return relationships.toOwnedSlice();
    }

    pub fn getMockRelationships(self: *LLMClient, group1: []const []const u8, group2: []const []const u8) ![]Relationship {
        log.debug("Generating mock relationships", .{});
        var relationships = std.ArrayList(Relationship).init(self.allocator);

        // Generate some mock relationships between ideas in the two groups
        for (group1, 0..) |idea1, i| {
            for (group2, 0..) |idea2, j| {
                // Create various relationship types based on position
                const rel_type = switch ((i + j) % 9) {
                    0 => graph.RelationType.implicative,
                    1 => graph.RelationType.hierarchical,
                    2 => graph.RelationType.analogous,
                    3 => graph.RelationType.causal,
                    4 => graph.RelationType.contradictory,
                    5 => graph.RelationType.part_whole,
                    6 => graph.RelationType.evolutionary,
                    7 => graph.RelationType.synonymous,
                    else => graph.RelationType.antonymous,
                };

                const certainty = 0.5 + (@as(f32, @floatFromInt((i + j) % 5)) / 10.0);

                const description = try std.fmt.allocPrint(
                    self.allocator,
                    "{s} relationship between '{s}' and '{s}'",
                    .{ rel_type.toString(), idea1, idea2 },
                );

                try relationships.append(.{
                    .from_idea = try self.allocator.dupe(u8, idea1),
                    .to_idea = try self.allocator.dupe(u8, idea2),
                    .relation_type = rel_type,
                    .certainty = certainty,
                    .description = description,
                });

                // Don't create relationships for every pair to keep it reasonable
                if ((i + j) % 3 != 0) break;
            }
        }

        return relationships.toOwnedSlice();
    }
};

pub const Relationship = struct {
    from_idea: []const u8,
    to_idea: []const u8,
    relation_type: graph.RelationType,
    certainty: f32,
    description: []const u8,

    pub fn deinit(self: *Relationship, allocator: std.mem.Allocator) void {
        allocator.free(self.from_idea);
        allocator.free(self.to_idea);
        allocator.free(self.description);
    }
};
