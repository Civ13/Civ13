<?php
declare(strict_types=1);

// Standalone offline entry point; loads no .env and injects every HTTP request.
require __DIR__ . '/../../tools/youtube/adapter.php';
require __DIR__ . '/../../tools/youtube/authorize-channel.php';

use React\EventLoop\StreamSelectLoop;
use React\Http\Message\Response;
use React\Promise\PromiseInterface;
use YouTube\Http\DriverInterface;
use YouTube\Http\Request;
use YouTube\YouTube;
use function React\Promise\resolve;
use function React\Promise\reject;

final class ScriptedDriver implements DriverInterface
{
    public array $requests = [];
    public function __construct(public array $responses) {}
    public function runRequest(Request $request, bool $streaming = false): PromiseInterface
    {
        $this->requests[] = $request;
        if ($this->responses === []) { throw new RuntimeException('Unexpected extra request'); }
        $response = array_shift($this->responses);
        return $response instanceof Throwable ? reject($response) : resolve($response);
    }
}

$assertions = 0;
function check(bool $condition): void
{
    global $assertions;
    ++$assertions;
    if (!$condition) { throw new RuntimeException('Offline framework assertion failed'); }
}
function refused(Closure $operation): void
{
    try { $operation(); } catch (Throwable $error) { check(true); return; }
    check(false);
}
function jsonResponse(array $value): Response { return new Response(200, [], json_encode($value, JSON_THROW_ON_ERROR)); }
function client(array $responses): array
{
    $loop = new StreamSelectLoop();
    $driver = new ScriptedDriver($responses);
    $guard = new FailClosedDriver($driver);
    $youtube = new YouTube(['token' => 'OFFLINE-FAKE-TOKEN', 'scopes' => REQUIRED_SCOPES, 'driver' => $guard, 'loop' => $loop]);
    return [$youtube, $loop, $driver, $guard];
}
function video(string $privacy = 'public', string $channel = TARGET_CHANNEL,
               string $processing = 'succeeded', string $status = 'processed'): array
{
    return ['items' => [['id' => 'abcdefghijk', 'snippet' => ['channelId' => $channel],
        'status' => ['privacyStatus' => $privacy, 'uploadStatus' => $status],
        'processingDetails' => ['processingStatus' => $processing]]]];
}

[$youtube, $loop, $driver] = client([jsonResponse(['items' => [['id' => TARGET_CHANNEL]]])]);
requireChannel($youtube, $loop);
check(str_contains($driver->requests[0]->getUrl(), 'mine=true'));
check($driver->requests[0]->getMethod() === 'GET');
$youtube->close();
[$youtube, $loop] = client([jsonResponse(['items' => [['id' => 'other-channel']]])]);
refused(fn () => requireChannel($youtube, $loop));
$youtube->close();

$path = tempnam(sys_get_temp_dir(), 'civ13-mocked-clip');
$bytes = str_repeat('offline fixture; not gameplay evidence', 40);
file_put_contents($path, $bytes);
$input = ['media_path' => $path, 'clip' => ['bytes' => strlen($bytes), 'sha256' => hash('sha256', $bytes)],
          'metadata' => ['title' => 'Offline metadata fixture', 'description' => 'Mocked request only; never uploaded.']];
try {
    [$youtube, $loop, $driver] = client([jsonResponse(['id' => 'abcdefghijk'])]);
    check(uploadClip($youtube, $loop, $input) === 'abcdefghijk');
    $request = $driver->requests[0];
    check($request->getEndpoint() === 'videos.insert');
    check($request->getMethod() === 'POST');
    check(str_contains($request->getUrl(), 'uploadType=multipart'));
    check(str_contains($request->getUrl(), 'notifySubscribers=false'));
    check(str_contains($request->getContent(), '"privacyStatus":"public"'));
    check(str_contains($request->getContent(), '"selfDeclaredMadeForKids":false'));
    check(!str_contains($request->getContent(), 'publishAt'));
    // Even a successful operation cannot be issued twice by this process.
    refused(fn () => uploadClip($youtube, $loop, $input));
    check(count($driver->requests) === 1);
    $youtube->close();

    foreach ([401, 429, 500, 503] as $status) {
        [$youtube, $loop, $driver] = client([new Response($status, [], '{"error":{"code":503,"message":"DO-NOT-LOG-SECRET"}}')]);
        refused(fn () => uploadClip($youtube, $loop, $input));
        check(count($driver->requests) === 1);
        $youtube->close();
    }
    [$youtube, $loop, $driver] = client([new RuntimeException('TOKEN-AND-URL-MUST-NOT-ESCAPE')]);
    refused(fn () => uploadClip($youtube, $loop, $input));
    check(count($driver->requests) === 1);
    $youtube->close();

    $bad = $input;
    $bad['clip']['sha256'] = str_repeat('0', 64);
    [$youtube, $loop, $driver] = client([]);
    refused(fn () => uploadClip($youtube, $loop, $bad));
    check(count($driver->requests) === 0);
    $youtube->close();
} finally { unlink($path); }

foreach ([video(privacy: 'unlisted'), video(privacy: 'private'), video(channel: 'other-channel'),
          video(processing: 'failed'), video(status: 'rejected'), ['items' => []]] as $response) {
    [$youtube, $loop, $driver] = client([jsonResponse($response)]);
    refused(fn () => verifyVideo($youtube, $loop, 'abcdefghijk'));
    check(count($driver->requests) === 1);
    $youtube->close();
}
[$youtube, $loop, $driver] = client([jsonResponse(video())]);
verifyVideo($youtube, $loop, 'abcdefghijk');
check(str_contains($driver->requests[0]->getUrl(), 'processingDetails'));
$youtube->close();

$waits = 0;
[$youtube, $loop, $driver] = client(array_fill(0, 12, jsonResponse(video(processing: 'processing', status: 'uploaded'))));
refused(function () use ($youtube, $loop, &$waits): void {
    verifyVideo($youtube, $loop, 'abcdefghijk', function () use (&$waits): void { ++$waits; });
});
check(count($driver->requests) === 12 && $waits === 11);
check(array_all($driver->requests, fn ($request) => $request->getMethod() === 'GET'));
$youtube->close();

// Errors on reads also stop rather than silently retrying behind the quota gate.
foreach ([new Response(503), new RuntimeException('network stopped')] as $failure) {
    [$youtube, $loop, $driver] = client([$failure]);
    refused(fn () => requireChannel($youtube, $loop));
    check(count($driver->requests) === 1);
    $youtube->close();
}

validateScopes(['scope' => REQUIRED_SCOPES, 'access_token' => 'fake', 'token_type' => 'Bearer']);
foreach ([[], [REQUIRED_SCOPES[1]], [...REQUIRED_SCOPES, 'https://www.googleapis.com/auth/youtube']] as $scopes) {
    refused(fn () => validateScopes(['scope' => $scopes, 'access_token' => 'fake', 'token_type' => 'Bearer']));
}
[$youtube, $loop, $driver, $guard] = client([]);
waitFor($loop, $guard->runRequest(new Request('videos.insert', 'POST', 'https://evil.invalid/upload')));
check(count($driver->requests) === 0);
$youtube->close();

echo "YoutubePHP offline contracts passed: {$assertions} assertions; no network, grant or upload\n";

$bootstrapToken = ['scope' => REQUIRED_SCOPES, 'token_type' => 'Bearer', 'access_token' => 'OFFLINE-FAKE'];
$bootstrapDriver = new ScriptedDriver([jsonResponse(['items' => [['id' => TARGET_CHANNEL]]])]);
check(checkBootstrapChannel($bootstrapToken, $bootstrapDriver) === TARGET_CHANNEL);
check(count($bootstrapDriver->requests) === 1 && $bootstrapDriver->requests[0]->getEndpoint() === 'channels.list');
$bootstrapDriver = new ScriptedDriver([jsonResponse(['items' => [['id' => 'wrong-channel']]])]);
refused(fn () => checkBootstrapChannel($bootstrapToken, $bootstrapDriver));
check(count($bootstrapDriver->requests) === 1);
echo "YoutubePHP bootstrap channel contracts passed; total {$assertions} assertions; no OAuth or upload\n";
