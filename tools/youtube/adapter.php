<?php
declare(strict_types=1);

// No bootstrap with .env, token store, logger, device flow or automatic reauth.
require __DIR__ . '/vendor/autoload.php';

use Psr\Http\Message\ResponseInterface;
use React\EventLoop\LoopInterface;
use React\EventLoop\StreamSelectLoop;
use React\Http\Message\Response;
use React\Promise\PromiseInterface;
use YouTube\Auth\OAuth;
use YouTube\Http\DriverInterface;
use YouTube\Http\Drivers\React as ReactDriver;
use YouTube\Http\Media;
use YouTube\Http\Request;
use YouTube\YouTube;
use function React\Promise\resolve;

const TARGET_CHANNEL = 'UCFRx_n3Mh3FfvL9yOUfG-yw';
const REQUIRED_SCOPES = ['https://www.googleapis.com/auth/youtube.readonly', 'https://www.googleapis.com/auth/youtube.upload'];

final class ProviderRateStop extends RuntimeException
{
    public function __construct(public readonly array $metadata) { parent::__construct('Provider stopped'); }
}

function safeRetryAt(ResponseInterface $response, int $now): int
{
    $values = [];
    $raw = $response->getHeaderLine('Retry-After');
    if (preg_match('/^[0-9]{1,7}$/D', $raw)) { $values[] = $now + (int) $raw; }
    elseif (strlen($raw) <= 80) {
        $date = DateTimeImmutable::createFromFormat('!D, d M Y H:i:s \\G\\M\\T', $raw, new DateTimeZone('UTC'));
        if ($date !== false && $date->format('D, d M Y H:i:s \\G\\M\\T') === $raw) { $values[] = $date->getTimestamp(); }
    }
    $reset = $response->getHeaderLine('X-RateLimit-Reset');
    if (preg_match('/^[0-9]{1,12}$/D', $reset)) { $values[] = (int) $reset; }
    $values = array_filter($values, static fn (int $value): bool => $value >= $now && $value <= $now + 604800);
    return $values === [] ? $now + 86400 : max($now + 60, ...$values);
}

/**
 * The pinned framework retries 503/429 responses, including POST. Convert every
 * error (including network failures) to a sanitized nonretryable response. The
 * additional write counter rejects even a higher-level client's replay attempt.
 * This is an adapter policy; it does not modify YoutubePHP or hide a success.
 */
final class FailClosedDriver implements DriverInterface
{
    private bool $writeSent = false;
    private ?array $limit = null;
    public function __construct(private DriverInterface $inner) {}
    public function rateLimit(): ?array { return $this->limit; }

    private function stopped(): Response
    {
        return new Response(400, ['Content-Type' => 'application/json'],
            '{"error":{"code":400,"message":"Upload stopped; reconcile durable receipt before retry"}}');
    }

    public function runRequest(Request $request, bool $streaming = false): PromiseInterface
    {
        $url = parse_url($request->getUrl());
        $allowed = [
            'oauth.token' => ['POST', 'oauth2.googleapis.com', '/token'],
            'channels.list' => ['GET', 'youtube.googleapis.com', '/youtube/v3/channels'],
            'videos.list' => ['GET', 'youtube.googleapis.com', '/youtube/v3/videos'],
            'videos.insert' => ['POST', 'youtube.googleapis.com', '/upload/youtube/v3/videos'],
        ];
        $route = [$request->getMethod(), $url['host'] ?? '', $url['path'] ?? ''];
        if ($streaming || ($url['scheme'] ?? '') !== 'https' || isset($url['user']) || isset($url['pass']) ||
            isset($url['port']) || ($allowed[$request->getEndpoint()] ?? null) !== $route) {
            return resolve($this->stopped());
        }
        if ($request->getEndpoint() === 'videos.insert') {
            if ($this->writeSent) {
                return resolve($this->stopped());
            }
            $this->writeSent = true; // Set BEFORE handing bytes to the driver.
        }
        return $this->inner->runRequest($request, false)->then(
            function (ResponseInterface $response): ResponseInterface {
                if ($response->getStatusCode() < 200 || $response->getStatusCode() >= 300 ||
                    $response->getBody()->getSize() > 1048576) {
                    $status = $response->getStatusCode();
                    $quota = false;
                    if ($status === 403 && $response->getBody()->getSize() <= 1048576) {
                        $body = json_decode((string) $response->getBody(), true);
                        foreach (($body['error']['errors'] ?? []) as $error) {
                            if (in_array($error['reason'] ?? null,
                                ['quotaExceeded', 'dailyLimitExceeded', 'rateLimitExceeded', 'userRateLimitExceeded'], true)) { $quota = true; }
                        }
                    }
                    if ($status === 429 || $quota) {
                        $this->limit = ['kind' => 'rate_limit', 'status' => $status,
                            'retry_at' => safeRetryAt($response, time()), 'media_attempted' => $this->writeSent];
                    }
                    return $this->stopped();
                }
                return $response;
            },
            fn (Throwable $error): ResponseInterface => $this->stopped()
        );
    }
}

function waitFor(LoopInterface $loop, PromiseInterface $promise): mixed
{
    $result = null;
    $error = null;
    $complete = false;
    $promise->then(
        function ($value) use (&$result, &$complete, $loop): void { $result = $value; $complete = true; $loop->stop(); },
        function (Throwable $failure) use (&$error, &$complete, $loop): void { $error = $failure; $complete = true; $loop->stop(); }
    );
    if (!$complete) { $loop->run(); }
    if (!$complete || $error !== null) { throw new RuntimeException('Service call stopped'); }
    return $result;
}

function requireChannel(YouTube $youtube, LoopInterface $loop): void
{
    $result = waitFor($loop, $youtube->channels->list(part: 'id', mine: true));
    if (count($result->items) !== 1 || $result->items->first()->id !== TARGET_CHANNEL) {
        throw new RuntimeException('Wrong channel');
    }
}

function uploadClip(YouTube $youtube, LoopInterface $loop, array $input): string
{
    $clip = $input['clip'];
    $path = $input['media_path'];
    if (!is_string($path) || !is_file($path) || is_link($path) ||
        filesize($path) !== $clip['bytes'] || $clip['bytes'] < 1024 || $clip['bytes'] > 33554432 ||
        hash_file('sha256', $path) !== $clip['sha256']) {
        throw new RuntimeException('Media integrity mismatch');
    }
    $metadata = $input['metadata'];
    $video = waitFor($loop, $youtube->videos->insert(
        part: 'snippet,status',
        body: ['snippet' => ['title' => $metadata['title'], 'description' => $metadata['description'], 'categoryId' => '20'],
               'status' => ['privacyStatus' => 'public', 'selfDeclaredMadeForKids' => false, 'containsSyntheticMedia' => false]],
        media: Media::fromFile($path, 'video/mp4'),
        notifySubscribers: false
    ));
    if (!is_string($video->id) || !preg_match('/^[A-Za-z0-9_-]{11}$/D', $video->id)) {
        throw new RuntimeException('Missing video ID; outcome uncertain');
    }
    return $video->id;
}

function verifyVideo(YouTube $youtube, LoopInterface $loop, string $id, ?Closure $sleep = null): void
{
    if (!preg_match('/^[A-Za-z0-9_-]{11}$/D', $id)) { throw new RuntimeException('Invalid video ID'); }
    $sleep ??= static function (): void { sleep(10); };
    for ($i = 0; $i < 12; ++$i) {
        $result = waitFor($loop, $youtube->videos->list(part: 'snippet,status,processingDetails', id: $id));
        if (count($result->items) !== 1) { throw new RuntimeException('Missing owner readback'); }
        $video = $result->items->first();
        if ($video->id !== $id || $video->snippet->channelId !== TARGET_CHANNEL ||
            $video->status->privacyStatus !== 'public' ||
            in_array($video->status->uploadStatus, ['failed', 'rejected', 'deleted'], true) ||
            in_array($video->processingDetails?->processingStatus, ['failed', 'terminated'], true)) {
            throw new RuntimeException('Video channel/visibility/processing mismatch');
        }
        if ($video->status->uploadStatus === 'processed' && $video->processingDetails?->processingStatus === 'succeeded') { return; }
        if ($i < 11) { $sleep(); }
    }
    throw new RuntimeException('Processing pending; verify known ID only');
}

function validateScopes(array $token): void
{
    $scopes = $token['scope'] ?? [];
    sort($scopes);
    if ($scopes !== REQUIRED_SCOPES || strtolower($token['token_type'] ?? '') !== 'bearer' ||
        !is_string($token['access_token'] ?? null)) {
        throw new RuntimeException('Grant scope mismatch');
    }
}

function adapterMain(): void
{
    $raw = stream_get_contents(STDIN, 1048577);
    if (strlen($raw) > 1048576) { throw new RuntimeException('Input cap'); }
    $input = json_decode($raw, true, 32, JSON_THROW_ON_ERROR);
    $mode = $input['mode'] ?? '';
    if (!in_array($mode, ['channel', 'upload', 'verify'], true)) { throw new RuntimeException('Unsupported operation'); }
    $loop = new StreamSelectLoop();
    $driver = new FailClosedDriver(new ReactDriver($loop, [], 120.0));
    try {
    $oauth = new OAuth((string) getenv('YOUTUBE_CLIENT_ID'), (string) getenv('YOUTUBE_CLIENT_SECRET'), $driver);
    $token = waitFor($loop, $oauth->refreshToken((string) getenv('YOUTUBE_REFRESH_TOKEN')));
    validateScopes($token);
    // Access token only: no automatic refresh, store, prompt or device-code flow.
    $youtube = new YouTube(['token' => $token['access_token'], 'scopes' => REQUIRED_SCOPES,
                           'driver' => $driver, 'loop' => $loop]);
    try {
        requireChannel($youtube, $loop);
        $result = match ($mode) {
            'channel' => ['channel_id' => TARGET_CHANNEL],
            'upload' => ['video_id' => uploadClip($youtube, $loop, $input)],
            'verify' => (function () use ($youtube, $loop, $input): array {
                verifyVideo($youtube, $loop, $input['video_id']);
                return ['verified' => true];
            })(),
        };
        echo json_encode($result, JSON_THROW_ON_ERROR), "\n";
    } finally {
        $youtube->close();
    }
    } catch (Throwable $error) {
        if ($driver->rateLimit() !== null) { throw new ProviderRateStop($driver->rateLimit()); }
        throw $error;
    }
}

if (realpath($_SERVER['SCRIPT_FILENAME'] ?? '') === __FILE__) {
    try { adapterMain(); }
    catch (Throwable $error) {
        if ($error instanceof ProviderRateStop) { echo json_encode($error->metadata, JSON_THROW_ON_ERROR), "\n"; }
        // Never emit exception messages, traces, tokens, media or service bodies.
        fwrite(STDERR, "YoutubePHP operation stopped; inspect durable receipt before retry\n");
        exit(1);
    }
}
