// Offline fake-DOM controls. These are NOT a native client/rendering receipt.
"use strict";
const fs = require("fs");
const vm = require("vm");
const assert = require("assert");
const code = fs.readFileSync(require("path").join(__dirname, "connected_notice_observer.js"), "utf8");
function exercise(defect) {
    let callback;
    const frames = [];
    const location = {href: ""};
    const window = {
        location, innerHeight: 600, innerWidth: 800, performance: {now: () => 123.5},
        requestAnimationFrame: fn => frames.push(fn),
        getComputedStyle: () => ({display: defect === "hidden" ? "none" : "block", visibility: "visible", opacity: "1"})
    };
    const context = {window, document: {getElementById: id => id === "messages" ? {} : null},
        MutationObserver: class {constructor(fn) { callback = fn; } observe() {}},
        JSON, Object, Array, String, Number, encodeURIComponent, decodeURIComponent};
    vm.runInNewContext(code, context);
    if (defect !== "unarmed") window.flaxSceneArm(encodeURIComponent(JSON.stringify({
        scene_id: "offline-scene", token: "offline-action", needle: "snap back into the main unit", item_label: "PADDLES-ID"
    })));
    const node = {nodeType: 1, isConnected: defect !== "detached",
        textContent: defect === "wrong_notice" ? "unrelated text" : "The PADDLES-ID snap back into the main unit.",
        getBoundingClientRect: () => ({width: defect === "zero_size" ? 0 : 100, height: 20,
            bottom: 100, right: 100, top: defect === "offscreen" ? 900 : 50, left: 10})};
    callback([{addedNodes: [node]}]);
    if (defect === "duplicate_arm") window.flaxSceneArm(encodeURIComponent(JSON.stringify({
        scene_id: "offline-scene", token: "offline-action", needle: "snap back into the main unit", item_label: "PADDLES-ID"
    })));
    if (defect === "stale_token") window.flaxSceneArm(encodeURIComponent(JSON.stringify({
        scene_id: "offline-scene", token: "new-action", needle: "snap back into the main unit", item_label: "PADDLES-ID"
    })));
    while (frames.length) frames.shift()();
    if (defect && defect !== "duplicate_arm") assert.strictEqual(location.href, "", defect + " must not report a notice");
    else {
        assert(location.href.startsWith("byond://?"));
        const query = new URLSearchParams(location.href.split("?")[1]);
        assert.strictEqual(query.get("token"), "offline-action");
        assert.strictEqual(query.get("text"), node.textContent);
        assert.strictEqual(query.get("browser_time"), "123.5");
    }
}
exercise(null);
exercise("duplicate_arm");
for (const defect of ["unarmed", "wrong_notice", "hidden", "detached", "zero_size", "offscreen", "stale_token"]) exercise(defect);
console.log("PASS: offline DOM observer, duplicate-action arm and seven rejection controls; no native/browser launch");
