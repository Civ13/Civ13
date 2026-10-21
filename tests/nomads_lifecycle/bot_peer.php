<?php
declare(strict_types=1);
// Explicit immutable adapter/dependency inputs; no bot bootstrap, .env, network or game.
$loader = require $argv[2];
$loader->addPsr4('Civ13\\', $argv[1].'/src/Civ13/', true);
$profile = json_decode(file_get_contents($argv[3]), true, 16, JSON_THROW_ON_ERROR);
$server = reset($profile['servers']);
$loop = new React\EventLoop\StreamSelectLoop();
$adapter = new Civ13\NativeLifecycle($server['native_lifecycle'], $server, $profile['gitdir'], $loop);
$exit = 1;
$adapter->request('start')->then(
    static function (array $result) use ($loop, &$exit): void { echo json_encode($result, JSON_THROW_ON_ERROR); $exit=0; $loop->stop(); },
    static function () use ($loop): void { fwrite(STDERR, "Peer request rejected\n"); $loop->stop(); }
);
$loop->addTimer(8, static function () use ($loop): void { $loop->stop(); });
$loop->run();
exit($exit);
