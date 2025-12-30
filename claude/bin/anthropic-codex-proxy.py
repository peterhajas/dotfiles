#!/usr/bin/env python3
"""
Anthropic → Codex Proxy Server
Implements Anthropic Messages API and translates to Codex MCP protocol
"""

import json
import subprocess
import sys
import time
import threading
import queue
from flask import Flask, request, jsonify
import os

app = Flask(__name__)

# Global state
conversation_map = {}  # sessionId -> conversationId

class MCPClient:
    """Thread-safe client for Codex MCP server via stdio"""

    def __init__(self):
        self.process = None
        self.request_id = 0
        self.pending = {}  # request_id -> Queue
        self.lock = threading.Lock()
        self.reader_thread = None
        self.process_dead = False

    def start(self):
        """Start the Codex MCP server process and reader thread"""
        with self.lock:
            if self.process and not self.process_dead:
                return

            # Reset state if restarting
            self.process_dead = False

            print("[MCP] Starting codex mcp-server...", file=sys.stderr)
            self.process = subprocess.Popen(
                ['codex', 'mcp-server'],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                bufsize=1
            )

            # Start reader thread
            self.reader_thread = threading.Thread(target=self._read_responses, daemon=True)
            self.reader_thread.start()

    def _read_responses(self):
        """Reader thread: routes responses to correct waiting request"""
        while self.process and self.process.stdout:
            try:
                line = self.process.stdout.readline()
                if not line:
                    print("[MCP] Process stdout closed, marking dead", file=sys.stderr)
                    break

                response = json.loads(line)

                # Skip event notifications
                if response.get('method') == 'codex/event':
                    event_type = response.get('params', {}).get('msg', {}).get('type', 'unknown')
                    print(f"[MCP] Event: {event_type}", file=sys.stderr)
                    continue

                # Route to waiting request
                req_id = response.get('id')
                if req_id:
                    with self.lock:
                        response_queue = self.pending.get(req_id)

                    if response_queue:
                        response_queue.put(response)
                        print(f"[MCP] Routed response {req_id} to waiting request", file=sys.stderr)
                    else:
                        print(f"[MCP] No waiting request for response {req_id}", file=sys.stderr)

            except json.JSONDecodeError as e:
                print(f"[MCP] Failed to parse: {line[:200]}", file=sys.stderr)
                continue
            except Exception as e:
                print(f"[MCP] Reader error: {e}", file=sys.stderr)

        # Process died - notify all pending requests
        self._notify_process_dead()

    def _notify_process_dead(self):
        """Notify all pending requests that the process died"""
        with self.lock:
            self.process_dead = True
            pending_copy = dict(self.pending)

        print(f"[MCP] Notifying {len(pending_copy)} pending requests of process death", file=sys.stderr)
        for req_id, response_queue in pending_copy.items():
            response_queue.put({'error': {'message': 'Codex process died unexpectedly'}})

    def call(self, tool_name, arguments):
        """Call a Codex MCP tool (thread-safe)"""
        self.start()

        # Check if process is still alive
        if self.process_dead or (self.process and self.process.poll() is not None):
            print("[MCP] Process was dead, restarting...", file=sys.stderr)
            self.process = None
            self.process_dead = False
            self.start()

        # Get unique request ID
        with self.lock:
            self.request_id += 1
            req_id = self.request_id
            # Create queue for this request
            response_queue = queue.Queue()
            self.pending[req_id] = response_queue

        try:
            # Send request
            request = {
                'jsonrpc': '2.0',
                'id': req_id,
                'method': 'tools/call',
                'params': {
                    'name': tool_name,
                    'arguments': arguments
                }
            }

            request_json = json.dumps(request) + '\n'
            print(f"[MCP] Sending request ID {req_id}", file=sys.stderr)
            try:
                self.process.stdin.write(request_json)
                self.process.stdin.flush()
            except (BrokenPipeError, OSError) as e:
                raise Exception(f"Failed to write to Codex process: {e}")

            # Wait for response on our queue (with timeout)
            print(f"[MCP] Waiting for response to request {req_id}...", file=sys.stderr)
            try:
                response = response_queue.get(timeout=120.0)
            except queue.Empty:
                raise Exception(f"MCP request {req_id} timeout after 120s")

            # Process response
            if 'result' in response:
                print(f"[MCP] Got result for request {req_id}", file=sys.stderr)
                return response['result']
            elif 'error' in response:
                raise Exception(f"MCP error: {response['error']}")
            else:
                raise Exception(f"Invalid MCP response: {response}")

        finally:
            # Clean up
            with self.lock:
                self.pending.pop(req_id, None)

# Global MCP client
mcp_client = MCPClient()

def translate_request(anthropic_req):
    """Translate Anthropic Messages API request to Codex MCP call"""
    # Extract the last user message
    messages = anthropic_req.get('messages', [])
    if not messages:
        raise ValueError("No messages in request")

    last_message = messages[-1]

    # Handle both string and structured content
    content = last_message.get('content', '')
    if isinstance(content, list):
        # Extract text from content blocks
        prompt = ' '.join(block.get('text', '') for block in content if block.get('type') == 'text')
    else:
        prompt = content

    # Check for existing conversation
    session_id = anthropic_req.get('metadata', {}).get('session_id', 'default')
    conversation_id = conversation_map.get(session_id)

    # Read model config from environment (set by wrapper)
    model = os.environ.get('CODEX_MODEL', 'gpt-5.2-codex')
    reasoning = os.environ.get('CODEX_REASONING', 'medium')

    if conversation_id:
        # Continue existing conversation
        return 'codex-reply', {
            'prompt': prompt,
            'conversationId': conversation_id
        }
    else:
        # Start new conversation with configured model
        return 'codex', {
            'prompt': prompt,
            'model': model,
            'model_reasoning_effort': reasoning,
            'cwd': os.getcwd()
        }

def translate_response(codex_resp, original_req):
    """Translate Codex MCP response to Anthropic Messages API format"""
    # Store conversation ID if present
    if 'conversationId' in codex_resp:
        session_id = original_req.get('metadata', {}).get('session_id', 'default')
        conversation_map[session_id] = codex_resp['conversationId']

    # Extract text from response
    if isinstance(codex_resp, dict):
        if 'content' in codex_resp and isinstance(codex_resp['content'], list):
            text = codex_resp['content'][0].get('text', '')
        else:
            text = str(codex_resp.get('result', ''))
    else:
        text = str(codex_resp)

    # Return in Anthropic format
    return {
        'id': f'msg_{int(time.time() * 1000)}',
        'type': 'message',
        'role': 'assistant',
        'content': [{
            'type': 'text',
            'text': text
        }],
        'model': original_req.get('model', 'claude-sonnet-4-5'),
        'stop_reason': 'end_turn',
        'usage': {
            'input_tokens': 0,
            'output_tokens': 0
        }
    }

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({'status': 'ok', 'service': 'anthropic-codex-proxy'})

@app.route('/v1/messages', methods=['POST'])
def messages():
    """Main Anthropic Messages API endpoint"""
    try:
        data = request.json
        print(f"[Proxy] Received request: {json.dumps(data, indent=2)}", file=sys.stderr)

        # Translate request
        tool_name, arguments = translate_request(data)
        print(f"[Proxy] Translated to Codex: {tool_name} with {arguments}", file=sys.stderr)

        # Call Codex MCP synchronously
        codex_response = mcp_client.call(tool_name, arguments)

        print(f"[Proxy] Codex response: {json.dumps(codex_response, indent=2)}", file=sys.stderr)

        # Translate response
        anthropic_response = translate_response(codex_response, data)

        return jsonify(anthropic_response)

    except Exception as e:
        print(f"[Proxy] Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PROXY_PORT', 3000))
    print(f"[Proxy] Anthropic→Codex proxy listening on http://localhost:{port}", file=sys.stderr)
    app.run(host='127.0.0.1', port=port, debug=False)
