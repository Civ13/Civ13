/* The server provides the eligible styles as numbered options. Preview swaps
 * are local; only Apply sends the chosen pair back to the server. */
(function () {
    function init() {
        var panel = document.getElementById('grooming-preview');
        var hair = document.getElementById('groom-hair');
        var beard = document.getElementById('groom-beard');
        var apply = document.getElementById('groom-apply');
        function layer(select, id, view) {
            var img = document.getElementById(id);
            var option = select.options[select.selectedIndex];
            var file = option && option.getAttribute('data-' + view);
            if (file) {
                img.src = file;
                img.style.display = '';
            } else {
                img.style.display = 'none';
            }
        }
        function render() {
            layer(hair, 'scalp-front', 'front');
            layer(hair, 'scalp-side', 'side');
            layer(beard, 'beard-front', 'front');
            layer(beard, 'beard-side', 'side');
            apply.disabled = hair.selectedIndex === 0 && beard.selectedIndex === 0;
        }
        hair.onchange = render;
        beard.onchange = render;
        apply.onclick = function () {
            if (apply.disabled) { return false; }
            var ref = panel.getAttribute('data-ref');
            var nonce = panel.getAttribute('data-nonce');
            // Keep BYOND's native reference syntax without accepting a URL.
            if (!/^(?:\[0x[0-9a-f]+\]|0x[0-9a-f]+)$/i.test(ref) ||
                    !/^[0-9a-f]{32}$/i.test(nonce)) { return false; }
            apply.disabled = true;
            window.location.href = 'byond://?src=' + ref + ';groom=apply;nonce=' + nonce +
                ';hair=' + (hair.selectedIndex + 1) + ';beard=' + (beard.selectedIndex + 1);
            return false;
        };
        render();
    }
    window.onload = init;
}());
