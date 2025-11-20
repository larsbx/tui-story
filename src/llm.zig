const std = @import("std");
const graph = @import("graph");

const log = std.log.scoped(.llm);

/// Supported API providers
pub const APIProvider = enum {
    anthropic,
    openai,
    custom,

    pub fn fromString(s: []const u8) APIProvider {
        if (std.ascii.eqlIgnoreCase(s, "anthropic")) return .anthropic;
        if (std.ascii.eqlIgnoreCase(s, "openai")) return .openai;
        return .custom;
    }
};

/// Configuration for API resilience
const APIConfig = struct {
    max_retries: u8 = 3,
    timeout_ms: u64 = 30_000, // 30 seconds
    initial_backoff_ms: u64 = 1_000, // 1 second
};

/// Provider-specific configuration
const ProviderConfig = struct {
    provider: APIProvider,
    model: []const u8,
    api_endpoint: []const u8,
    auth_header: []const u8, // e.g., "x-api-key" or "Authorization"
    auth_prefix: []const u8, // e.g., "" or "Bearer "
};

pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    api_key: ?[]const u8,
    http_client: std.http.Client,
    config: APIConfig,
    provider_config: ProviderConfig,

    pub fn init(allocator: std.mem.Allocator) LLMClient {
        // Detect provider from environment (defaults to Anthropic for backward compatibility)
        const provider_str = std.process.getEnvVarOwned(allocator, "LLM_PROVIDER") catch null;
        const provider = if (provider_str) |p| blk: {
            defer allocator.free(p);
            break :blk APIProvider.fromString(p);
        } else .anthropic;

        // Get API key based on provider
        const api_key = switch (provider) {
            .anthropic => std.process.getEnvVarOwned(allocator, "ANTHROPIC_API_KEY") catch null,
            .openai => std.process.getEnvVarOwned(allocator, "OPENAI_API_KEY") catch null,
            .custom => std.process.getEnvVarOwned(allocator, "LLM_API_KEY") catch null,
        };

        // Configure provider-specific settings
        const provider_config = switch (provider) {
            .anthropic => ProviderConfig{
                .provider = .anthropic,
                .model = std.process.getEnvVarOwned(allocator, "LLM_MODEL") catch "claude-3-5-sonnet-20241022",
                .api_endpoint = std.process.getEnvVarOwned(allocator, "LLM_API_ENDPOINT") catch "https://api.anthropic.com/v1/messages",
                .auth_header = "x-api-key",
                .auth_prefix = "",
            },
            .openai => ProviderConfig{
                .provider = .openai,
                .model = std.process.getEnvVarOwned(allocator, "LLM_MODEL") catch "gpt-4",
                .api_endpoint = std.process.getEnvVarOwned(allocator, "LLM_API_ENDPOINT") catch "https://api.openai.com/v1/chat/completions",
                .auth_header = "Authorization",
                .auth_prefix = "Bearer ",
            },
            .custom => ProviderConfig{
                .provider = .custom,
                .model = std.process.getEnvVarOwned(allocator, "LLM_MODEL") catch "default",
                .api_endpoint = std.process.getEnvVarOwned(allocator, "LLM_API_ENDPOINT") catch "http://localhost:8000/v1/chat/completions",
                .auth_header = std.process.getEnvVarOwned(allocator, "LLM_AUTH_HEADER") catch "Authorization",
                .auth_prefix = std.process.getEnvVarOwned(allocator, "LLM_AUTH_PREFIX") catch "Bearer ",
            },
        };

        if (api_key) |_| {
            log.info("LLM client initialized with {s} provider", .{@tagName(provider)});
        } else {
            log.warn("LLM client initialized without API key - using mock data", .{});
        }

        return .{
            .allocator = allocator,
            .api_key = api_key,
            .http_client = std.http.Client{ .allocator = allocator },
            .config = .{},
            .provider_config = provider_config,
        };
    }

    pub fn deinit(self: *LLMClient) void {
        if (self.api_key) |key| {
            self.allocator.free(key);
        }
        // Note: provider_config strings are static or from environment,
        // which are freed separately if dynamically allocated
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
        const api_key = self.api_key orelse return error.MissingAPIKey;

        // Start timeout timer
        const start_time = std.time.milliTimestamp();

        // Parse the endpoint URI
        const uri = try std.Uri.parse(self.provider_config.api_endpoint);

        // Prepare request buffer
        var server_header_buffer: [8192]u8 = undefined;

        // Open HTTP request
        var req = try self.http_client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        // Set headers
        req.transfer_encoding = .chunked;
        try req.headers.append("content-type", "application/json");

        // Set authentication header
        if (self.provider_config.auth_prefix.len > 0) {
            const auth_value = try std.fmt.allocPrint(
                self.allocator,
                "{s}{s}",
                .{ self.provider_config.auth_prefix, api_key },
            );
            defer self.allocator.free(auth_value);
            try req.headers.append(self.provider_config.auth_header, auth_value);
        } else {
            try req.headers.append(self.provider_config.auth_header, api_key);
        }

        // Add provider-specific headers
        if (self.provider_config.provider == .anthropic) {
            try req.headers.append("anthropic-version", "2023-06-01");
        }

        // Build request body based on provider
        var request_body = std.ArrayList(u8).init(self.allocator);
        defer request_body.deinit();

        try self.buildRequestBody(&request_body, prompt);

        // Check timeout before sending
        if (std.time.milliTimestamp() - start_time > self.config.timeout_ms) {
            return error.Timeout;
        }

        // Send request
        try req.send();
        try req.writeAll(request_body.items);
        try req.finish();

        // Wait for response
        try req.wait();

        // Check timeout after receiving response
        if (std.time.milliTimestamp() - start_time > self.config.timeout_ms) {
            return error.Timeout;
        }

        // Check HTTP status
        if (req.response.status != .ok) {
            log.err("HTTP request failed with status: {}", .{req.response.status});
            return error.HTTPRequestFailed;
        }

        // Read response body
        var response_body = std.ArrayList(u8).init(self.allocator);
        errdefer response_body.deinit();

        const reader = req.reader();
        try reader.readAllArrayList(&response_body, 1024 * 1024); // 1MB max

        // Extract text from response based on provider format
        return try self.extractResponseText(response_body.items);
    }

    fn buildRequestBody(self: *LLMClient, body: *std.ArrayList(u8), prompt: []const u8) !void {
        const writer = body.writer();

        switch (self.provider_config.provider) {
            .anthropic => {
                // Anthropic Messages API format
                try writer.writeAll("{\"model\":");
                try std.json.encodeJsonString(self.provider_config.model, .{}, writer);
                try writer.writeAll(",\"max_tokens\":4096,\"messages\":[{\"role\":\"user\",\"content\":");
                try std.json.encodeJsonString(prompt, .{}, writer);
                try writer.writeAll("}]}");
            },
            .openai, .custom => {
                // OpenAI Chat Completions format (widely compatible)
                try writer.writeAll("{\"model\":");
                try std.json.encodeJsonString(self.provider_config.model, .{}, writer);
                try writer.writeAll(",\"messages\":[{\"role\":\"user\",\"content\":");
                try std.json.encodeJsonString(prompt, .{}, writer);
                try writer.writeAll("}]}");
            },
        }
    }

    fn extractResponseText(self: *LLMClient, response_body: []const u8) ![]const u8 {
        // Parse JSON response
        const response_json = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response_body,
            .{},
        );
        defer response_json.deinit();

        const root = response_json.value;
        if (root != .object) {
            return error.InvalidResponseFormat;
        }

        // Extract based on provider format
        switch (self.provider_config.provider) {
            .anthropic => {
                // Anthropic format: {"content": [{"type": "text", "text": "..."}], ...}
                const content_field = root.object.get("content") orelse return error.MissingContentField;
                if (content_field != .array or content_field.array.items.len == 0) {
                    return error.InvalidContentFormat;
                }

                const first_content = content_field.array.items[0];
                if (first_content != .object) {
                    return error.InvalidContentFormat;
                }

                const text_field = first_content.object.get("text") orelse return error.MissingTextField;
                if (text_field != .string) {
                    return error.InvalidTextFormat;
                }

                return try self.allocator.dupe(u8, text_field.string);
            },
            .openai, .custom => {
                // OpenAI format: {"choices": [{"message": {"content": "..."}}], ...}
                const choices_field = root.object.get("choices") orelse return error.MissingChoicesField;
                if (choices_field != .array or choices_field.array.items.len == 0) {
                    return error.InvalidChoicesFormat;
                }

                const first_choice = choices_field.array.items[0];
                if (first_choice != .object) {
                    return error.InvalidChoiceFormat;
                }

                const message_field = first_choice.object.get("message") orelse return error.MissingMessageField;
                if (message_field != .object) {
                    return error.InvalidMessageFormat;
                }

                const content_field = message_field.object.get("content") orelse return error.MissingContentField;
                if (content_field != .string) {
                    return error.InvalidContentType;
                }

                return try self.allocator.dupe(u8, content_field.string);
            },
        }
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
