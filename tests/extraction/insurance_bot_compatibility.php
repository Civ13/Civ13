<?php
declare(strict_types=1);
// Validate only synthetic native fixtures. Never starts or connects a bot.
$botRoot = $argv[1] ?? throw new InvalidArgumentException('Pinned bot root required');
$source = $argv[2] ?? throw new InvalidArgumentException('Native fixture directory required');
foreach (['Transport', 'Client', 'AsyncSpool', 'Controller'] as $class) {
    require $botRoot.'/src/Civ13/Safehouse/'.$class.'.php';
}
use Civ13\Safehouse\AsyncSpool;
use Civ13\Safehouse\Controller;
function insuranceVerify(bool $condition, string $message): void {
    if (!$condition) { throw new RuntimeException($message); }
}
$manifest = json_decode(file_get_contents($source.'/manifest.json'), true, 32, JSON_THROW_ON_ERROR);
insuranceVerify($manifest['synthetic'] === 1 && $manifest['clock'] === 1000, 'Synthetic fixture metadata mismatch');
$spool = new AsyncSpool($source.'/spool', $manifest['key'], true, 10, static fn (): int => 1000);
$results = [];
foreach ($manifest['requests'] as $requestId => $fileId) {
    insuranceVerify(hash('sha256', $requestId) === $fileId, 'Immutable request filename mismatch');
    $reply = $spool->poll($fileId);
    insuranceVerify($reply['status'] === 'committed' && $reply['action'] === 'insurance.inspect', 'Native signed projection was not committed');
    $data = Controller::insuranceProjection($reply['data']);
    $state = substr($requestId, strlen('insurance-'));
    insuranceVerify(count($data['entries']) === 7 && $data['completed_generation'] === ($state === 'pending' ? 1 : 2), 'Native page/generation mismatch');
    foreach ($data['entries'] as $entry) {
        insuranceVerify($entry['state'] === $state && is_bool($entry['found_in_raid']), 'Native eligibility or JSON boolean mismatch');
    }
    insuranceVerify($data['expiration'] === 'to be implemented' && is_string($data['next_cursor']), 'Native expiration or paging mismatch');
    $results[$state] = $data;
    echo "PASS native signed insurance $state projection, condition, provenance and bounded cursor\n";
}
insuranceVerify($results['pending']['mail_revision'] === $results['eligible']['mail_revision'], 'Round completion must not mutate retained mail');
insuranceVerify($results['pending']['next_cursor'] === $results['eligible']['next_cursor'], 'Full completion changed the stable mail cursor');
