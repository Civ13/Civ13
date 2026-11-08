<?php
/** Offline prototype, NOT a deployable agent client. Reads only synthetic stdin. */
declare(strict_types=1);

const DUMMY_AGENT = 'offline-benchmark';
const DUMMY_TOKEN = 'not-a-real-token';

function encodeTopic(string $query): string {
    $data = '?' . $query;
    if (strlen($data) + 6 > 0xffff) {
        throw new RuntimeException('request too large');
    }
    return "\x00\x83" . pack('n', strlen($data) + 6) . str_repeat("\x00", 5) . $data . "\x00";
}

function decodeTopic(string $packet): string {
    // This prototype covers only the valid string reply used by this corpus.
    // Numeric/null/malformed packet behavior is deliberately not a port claim.
    if (strlen($packet) < 5 || substr($packet, 0, 2) !== "\x00\x83") {
        throw new RuntimeException('malformed reply');
    }
    $length = unpack('nlength', substr($packet, 2, 2))['length'];
    $body = substr($packet, 4, $length);
    if (substr($body, 0, 1) !== "\x06") {
        throw new RuntimeException('non-string reply outside benchmark contract');
    }
    return explode("\x00", substr($body, 1), 2)[0];
}

final class MockTransport {
    public string $packet = '';
    private string $reply;
    public function __construct(string $replyJson) {
        $body = "\x06" . $replyJson . "\x00";
        if (strlen($body) > 0xffff) {
            throw new RuntimeException('fixture exceeds Topic response limit');
        }
        $this->reply = "\x00\x83" . pack('n', strlen($body)) . $body;
    }
    public function __invoke(string $host, int $port, string $query, float $timeout): string {
        $this->packet = encodeTopic($query);
        return decodeTopic($this->reply);
    }
}

final class MockClient {
    public function __construct(private array $actions, public MockTransport $transport) {}
    public function request(string $action, object $args): object {
        if (!isset($this->actions[$action])) {
            throw new RuntimeException('unknown action');
        }
        $query = ['agent_control' => '1', 'agent' => DUMMY_AGENT, 'token' => DUMMY_TOKEN, 'action' => $action];
        if (count((array) $args)) {
            // Match Python's ensure_ascii=True and compact JSON for this corpus.
            $query['args'] = json_encode($args, JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR);
        }
        // urllib.parse.quote_plus leaves '~' unescaped; PHP's RFC1738 encoder does not.
        $encoded = str_replace('%7E', '~', http_build_query($query, '', '&', PHP_QUERY_RFC1738));
        $reply = ($this->transport)('127.0.0.1', 1714, $encoded, 15.0);
        return json_decode($reply, false, 512, JSON_THROW_ON_ERROR);
    }
}

function runWorker(object $payload): array {
    if ($payload->corpus->schema !== 1) {
        throw new RuntimeException('unsupported corpus schema');
    }
    $cases = $payload->corpus->cases;
    $actions = array_fill_keys($payload->corpus->actions, true);
    $clients = array_map(fn($c) => new MockClient($actions, new MockTransport($c->reply_json)), $cases);
    if ($payload->mode === 'parity') {
        $results = [];
        foreach ($cases as $i => $case) {
            $response = $clients[$i]->request($case->action, $case->args);
            $results[] = ['name' => $case->name, 'packet_hex' => bin2hex($clients[$i]->transport->packet), 'response' => $response];
        }
        return ['version' => PHP_VERSION, 'results' => $results, 'runtime' => [
            'extensions' => get_loaded_extensions(), 'opcache_enable_cli' => ini_get('opcache.enable_cli'),
            'opcache_jit' => ini_get('opcache.jit'), 'opcache_jit_buffer_size' => ini_get('opcache.jit_buffer_size')]];
    }
    $cycle = function() use ($cases, $clients): int {
        $checksum = 0;
        foreach ($cases as $i => $case) {
            $response = $clients[$i]->request($case->action, $case->args);
            $checksum += strlen($clients[$i]->transport->packet) + $response->data->revision;
        }
        return $checksum;
    };
    for ($i = 0; $i < $payload->warmup; $i++) {
        $cycle();
    }
    $start = hrtime(true);
    $checksum = 0;
    for ($i = 0; $i < $payload->iterations; $i++) {
        $checksum += $cycle();
    }
    $elapsed = hrtime(true) - $start;
    return ['version' => PHP_VERSION, 'elapsed_ns' => $elapsed,
            'operations' => $payload->iterations * count($cases), 'checksum' => $checksum];
}

try {
    $input = json_decode(stream_get_contents(STDIN), false, 512, JSON_THROW_ON_ERROR);
    echo json_encode(runWorker($input), JSON_UNESCAPED_SLASHES | JSON_THROW_ON_ERROR), "\n";
} catch (Throwable $error) {
    fwrite(STDERR, 'Benchmark worker failed: ' . $error->getMessage() . "\n");
    exit(1);
}
