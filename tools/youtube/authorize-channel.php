<?php
declare(strict_types=1);

require_once __DIR__ . '/adapter.php';

use React\EventLoop\LoopInterface;
use React\EventLoop\StreamSelectLoop;
use YouTube\Http\DriverInterface;
use YouTube\Http\Drivers\React as ReactDriver;
use YouTube\YouTube;

/** Read-only bootstrap check: no refresh credentials, store, prompt or upload. */
function checkBootstrapChannel(array $token, ?DriverInterface $driver = null, ?LoopInterface $loop = null): string
{
    validateScopes($token);
    $loop ??= new StreamSelectLoop();
    $youtube = new YouTube(['token' => $token['access_token'], 'scopes' => REQUIRED_SCOPES,
        'driver' => new FailClosedDriver($driver ?? new ReactDriver($loop, [], 20.0)), 'loop' => $loop]);
    try {
        requireChannel($youtube, $loop);
        return TARGET_CHANNEL;
    } finally { $youtube->close(); }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    try {
        $raw = stream_get_contents(STDIN, 32769);
        if (strlen($raw) > 32768) { throw new RuntimeException('Input cap'); }
        $token = json_decode($raw, true, 8, JSON_THROW_ON_ERROR);
        $id = checkBootstrapChannel($token);
        echo json_encode(['channel_id' => $id], JSON_THROW_ON_ERROR), "\n";
    } catch (Throwable $error) {
        fwrite(STDERR, "YoutubePHP bootstrap channel check stopped; no credentials printed\n");
        exit(1);
    }
}
