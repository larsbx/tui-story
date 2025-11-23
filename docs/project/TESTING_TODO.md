# Testing TODO List

This document tracks needed unit tests and test improvements for the Semantic Graph TUI project.

## High Priority - Concurrent MCP Server

### Thread Safety & Concurrency Tests

- [ ] **Stress test with high concurrent load** (tests/unit/mcp_server_concurrent_test.zig)
  - Spawn 50+ threads making simultaneous requests
  - Verify no data corruption or race conditions
  - Measure response time degradation under load

- [ ] **Edge update race condition test** (tests/unit/thread_safe_graph_test.zig)
  - Multiple threads updating the same edge with different certainty values
  - Verify final state is consistent (highest certainty wins)
  - Test with 10+ threads updating the same edge simultaneously

- [ ] **Concurrent read-write test** (tests/unit/thread_safe_graph_test.zig)
  - Some threads reading (snapshots, JSON serialization)
  - Other threads writing (add vertex, add edge)
  - Verify reads get consistent snapshots
  - No partial/torn reads

- [ ] **Graph layout calculation under concurrent access** (tests/unit/thread_safe_graph_test.zig)
  - Test calculateLayout() being called while graph is being modified
  - Currently calculateLayout() is not thread-safe if called externally

### HTTP Transport Tests

- [ ] **Malformed HTTP request handling** (tests/unit/mcp_server_concurrent_test.zig)
  - Invalid HTTP headers
  - Missing Content-Type
  - Malformed JSON body
  - Verify proper error responses

- [ ] **Large payload handling** (tests/unit/mcp_server_concurrent_test.zig)
  - Test with ideas > 1000 characters (should be rejected)
  - Test with very large JSON-RPC requests (close to 10MB limit)
  - Verify memory limits are enforced

- [ ] **Connection timeout tests** (tests/integration/mcp_http_integration_test.zig)
  - Slow client connections
  - Verify server doesn't hang
  - Test cleanup of stale connections

### Error Recovery Tests

- [ ] **Memory allocation failure simulation** (tests/unit/thread_safe_graph_test.zig)
  - Test behavior when allocator fails
  - Verify proper error propagation
  - No memory leaks on error paths

- [ ] **LLM API failure during concurrent requests** (tests/integration/)
  - Multiple threads calling analyze_idea when LLM fails
  - Verify consistent error handling
  - No corrupted graph state

## Medium Priority - Analysis Service

### Analysis Service with ThreadSafeGraph

- [ ] **Concurrent analyze_idea operations** (tests/integration/concurrent_analysis_test.zig)
  - Multiple threads analyzing different ideas simultaneously
  - Verify all relationships are correctly added
  - No duplicate or missing edges
  - **IMPORTANT**: This is the most complex concurrent operation

- [ ] **Sequential vs concurrent analysis consistency** (tests/integration/)
  - Run same analysis sequence sequentially and concurrently
  - Verify both produce equivalent graphs
  - Account for non-deterministic ordering

### Existing TODOs in analysis_service.zig

- [ ] **Add unit tests for AnalysisService.analyzeNewIdea()** (tests/unit/analysis_service_test.zig)
  - Test with mock LLM responses
  - Test with empty graph
  - Test with existing relationships
  - Test deduplication logic

## Low Priority - Existing Features

### LLM Client (from existing TODOs)

- [ ] **Add unit tests for callAPI()** (tests/unit/llm_test.zig)
  - Already has some tests, need edge cases
  - Test retry logic with different failure scenarios
  - Test timeout handling

- [ ] **Add unit tests for makeAPIRequest()** (tests/unit/llm_test.zig)
  - Test HTTP request construction
  - Test header formatting

- [ ] **Add unit tests for buildRequestBody()** (tests/unit/llm_test.zig)
  - Test different provider formats
  - Test prompt formatting

- [ ] **Add unit tests for extractResponseText()** (tests/unit/llm_test.zig)
  - Test different response structures
  - Test error responses

- [ ] **Add unit tests for parseResponse()** (tests/unit/llm_test.zig)
  - Test malformed JSON
  - Test missing fields

### Validation Layer

- [ ] **Add unit tests for validateVertexContent()** (tests/unit/validation_test.zig)
  - Test boundary conditions
  - Test special characters
  - Test UTF-8 validation

### UI Layer (low priority - not used in MCP mode)

- [ ] **Add unit tests for UIState.init()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for UIState.handleKey()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for UIState.analyzeNewIdea()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for UIState.reset()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for render()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for renderHelp()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for renderInput()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for renderAnalyzing()** (tests/unit/ui_test.zig)
- [ ] **Add unit tests for renderGraph()** (tests/unit/ui_test.zig)

## Integration Tests Needed

### HTTP MCP Server Integration

- [ ] **End-to-end HTTP workflow test** (tests/integration/mcp_http_integration_test.zig)
  - Start HTTP server in test
  - Make real HTTP requests
  - Verify responses
  - Shutdown cleanly

- [ ] **Multi-client collaborative session** (tests/integration/mcp_http_integration_test.zig)
  - Simulate realistic multi-agent scenario
  - Agent 1: Adds ideas A, B, C
  - Agent 2: Adds ideas D, E
  - Agent 3: Analyzes idea F (relates to all previous)
  - All running concurrently
  - Verify final graph has all expected vertices and edges

### Performance Benchmarks (optional)

- [ ] **Throughput benchmark** (tests/benchmarks/concurrent_throughput.zig)
  - Measure requests/second under various concurrency levels
  - Compare stdio vs HTTP performance
  - Identify performance bottlenecks

- [ ] **Latency benchmark** (tests/benchmarks/response_latency.zig)
  - Measure p50, p95, p99 latencies
  - Under different load levels
  - With and without LLM calls

## Test Infrastructure Improvements

- [ ] **Mock HTTP client for integration tests**
  - Create helper to make HTTP requests in tests
  - Simplify HTTP integration test writing

- [ ] **Concurrent test helper utilities**
  - Utilities for spawning test threads
  - Barrier synchronization for test coordination
  - Better assertion of concurrent invariants

- [ ] **Test fixtures for common graph structures**
  - Pre-populated graphs for testing
  - Common relationship patterns
  - Reduce test boilerplate

## Notes

### Critical Path for Production Readiness

The most important tests for concurrent MCP server are:

1. **Concurrent analyze_idea operations** - This is the most complex operation involving both reads and writes
2. **Stress test with high concurrent load** - Verify stability under realistic load
3. **Edge update race condition test** - Ensure consistency of the core data structure

### Known Limitations

- **Graph layout not thread-safe**: The `calculateLayout()` function in `SemanticGraph` is not currently thread-safe. It's only called in the TUI mode, not in MCP server mode, so this is acceptable for now.
- **HTTP server shutdown**: The HTTP server doesn't have graceful shutdown implemented yet. This should be added for production use.
- **Connection pooling**: No connection pooling or rate limiting. Could be added for production deployments.

### Test Coverage Goals

Current MCP test coverage:
- 15 stdio MCP server tests
- 4 MCP protocol integration tests
- 14 thread-safe graph tests
- 11 concurrent HTTP server tests
- **Total: 44 MCP-related tests**

Target coverage:
- Add 15-20 more tests for concurrent scenarios
- Add 5-10 HTTP integration tests
- Add 5-10 analysis service tests
- **Goal: 70-80 total MCP-related tests**

This would provide strong confidence in the concurrent implementation.
