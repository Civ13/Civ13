// Fixture-only observation of production chat DOM; no message injection.
// A client report is not independently verified rendered-pixel acceptance.
(function () {
    "use strict";
    let armed = null;
    let reported = false;
    const messages = document.getElementById("messages");
    if (!messages) return;
    window.flaxSceneArm = function (encoded) {
        const value = JSON.parse(decodeURIComponent(encoded));
        if (!value.scene_id || !value.token || !value.needle || !value.item_label) return;
        // Nested production paddle callbacks can send the same notice twice.
        // Re-arming the same action must not invalidate an already queued frame.
        if (armed && armed.scene_id === value.scene_id && armed.token === value.token) return;
        armed = value;
        reported = false;
    };
    function observe(node, expected) {
        window.requestAnimationFrame(function () {
            window.requestAnimationFrame(function () {
                if (reported || armed !== expected || !node.isConnected) return;
                const text = node.textContent || "";
                const normalized = text.toLowerCase();
                if (!normalized.includes(expected.needle.toLowerCase()) ||
                    !normalized.includes(expected.item_label.toLowerCase())) return;
                const box = node.getBoundingClientRect();
                const style = window.getComputedStyle(node);
                if (box.width <= 0 || box.height <= 0 || box.bottom <= 0 || box.right <= 0 ||
                    box.top >= window.innerHeight || box.left >= window.innerWidth ||
                    style.display === "none" || style.visibility === "hidden" || Number(style.opacity) === 0) return;
                reported = true;
                const fields = {flax_notice: "1", scene_id: expected.scene_id, token: expected.token,
                    text: text.slice(0, 1024), width: String(box.width), height: String(box.height),
                    browser_time: String(window.performance.now())};
                const query = Object.keys(fields).map(function (key) {
                    return encodeURIComponent(key) + "=" + encodeURIComponent(fields[key]);
                }).join("&");
                window.location.href = "byond://?" + query;
            });
        });
    }
    new MutationObserver(function (mutations) {
        if (!armed || reported) return;
        const expected = armed;
        mutations.forEach(function (mutation) {
            Array.prototype.forEach.call(mutation.addedNodes, function (node) {
                if (node.nodeType === 1) observe(node, expected);
            });
        });
    }).observe(messages, {childList: true, subtree: true});
}());
