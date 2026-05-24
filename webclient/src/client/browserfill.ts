const base = document.head.querySelector("base");
// Base is bad. Go away.
if (base) {
	base.parentElement?.removeChild(base);
}

// Polyfill IE-era attachEvent/detachEvent used by legacy BYOND browser scripts
function attachEventPolyfill(
	this: EventTarget,
	eventName: string,
	handler: EventListenerOrEventListenerObject,
) {
	const name = eventName.startsWith("on") ? eventName.slice(2) : eventName;
	this.addEventListener(name, handler);
}
function detachEventPolyfill(
	this: EventTarget,
	eventName: string,
	handler: EventListenerOrEventListenerObject,
) {
	const name = eventName.startsWith("on") ? eventName.slice(2) : eventName;
	this.removeEventListener(name, handler);
}

function resolveCallback(callback: string) {
	const parts = callback.split(".");
	let current: unknown = window;
	for (const part of parts) {
		if (!current || typeof current !== "object") return undefined;
		current = (current as Record<string, unknown>)[part];
	}
	return typeof current === "function" ? current : undefined;
}

// @ts-expect-error
if (!document.attachEvent)
	(document as any).attachEvent = attachEventPolyfill.bind(document);
// @ts-expect-error
if (!document.detachEvent)
	(document as any).detachEvent = detachEventPolyfill.bind(document);
// @ts-expect-error
if (!(window as any).attachEvent)
	(window as any).attachEvent = attachEventPolyfill.bind(window);
// @ts-expect-error
if (!(window as any).detachEvent)
	(window as any).detachEvent = detachEventPolyfill.bind(window);

const elementMouseDownEvents = new Map<
	EventListenerOrEventListenerObject,
	EventListener
>();
const originalElementAddEventListener = Element.prototype.addEventListener;
const originalElementRemoveEventListener =
	Element.prototype.removeEventListener;
const originalDocumentAddEventListener = document.addEventListener;
const originalDocumentRemoveEventListener = document.removeEventListener;
Element.prototype.addEventListener = function (
	...args: Parameters<Element["addEventListener"]>
) {
	if (args[0] == "mousedown") {
		args[0] = "pointerdown";

		const originalHandler = args[1];
		args[1] = ((e: PointerEvent) => {
			e.preventDefault();
			document.documentElement.setPointerCapture(e.pointerId);
			if ("handleEvent" in originalHandler) originalHandler.handleEvent(e);
			else originalHandler(e);
		}) as EventListener;
		elementMouseDownEvents.set(originalHandler, args[1]);
	}

	originalElementAddEventListener.apply(this, args);
};
Element.prototype.removeEventListener = function (
	...args: Parameters<Element["removeEventListener"]>
) {
	if (args[0] == "mousedown") {
		args[0] = "pointerdown";

		const originalHandler = args[1];
		args[1] = elementMouseDownEvents.get(originalHandler) ?? originalHandler;
		elementMouseDownEvents.delete(originalHandler);
	}

	originalElementRemoveEventListener.apply(this, args);
};
document.addEventListener = function (
	...args: Parameters<Document["addEventListener"]>
) {
	if (args[0].startsWith("mouse")) {
		args[0] = args[0].replace("mouse", "pointer");
	}
	originalDocumentAddEventListener.apply(this, args);
};
document.removeEventListener = function (
	...args: Parameters<Document["removeEventListener"]>
) {
	if (args[0].startsWith("mouse")) {
		args[0] = args[0].replace("mouse", "pointer");
	}
	originalDocumentRemoveEventListener.apply(this, args);
};

const window_output_map = Object.create(null) as any;
for (
	let thing = window;
	thing != null && thing != Object.getPrototypeOf(thing);
	thing = Object.getPrototypeOf(thing)
) {
	for (const key of Object.getOwnPropertyNames(thing)) {
		window_output_map[key] = {
			get() {
				return undefined;
			},
		};
	}
}
const window_output_target = Object.create(window, window_output_map);

// @ts-expect-error
const byond = (window.byond = {
	fixjs(fun: () => void) {
		if (typeof fun != "function")
			throw new Error("non-function passed to fixjs");
		try {
			new Function("")();
		} catch (e) {
			console.warn("Script execution is disabled - skipping browser fill");
			fun();
			return;
		}
		let str = fun.toString();
		const start = str.indexOf("{") + 1;
		const end = str.lastIndexOf("}");
		str = str.substring(start, end);
		str = str.replace(/window\.location/g, "window.__location_proxy");
		const tgui_patch_match = str.match(/\w.setupDrag\s*=\s*(\w);/);
		if (tgui_patch_match) {
			const setupDrag = tgui_patch_match[1];
			str = str.replace(/drag start(?:\n|.)*?,/, (x) => x + `${setupDrag}(),`);
			str = str.replace(/drag end(?:\n|.)*?,/, (x) => x + `${setupDrag}(),`);
		}
		str = str.replace("isStyleSheetLoaded(node, url)", "true");
		new Function(str)();
	},
	outputtarget: window_output_target,
	go(str: string) {
		window.parent.postMessage("go:" + str, "*");
	},
});

function decodeOutputPart(value: string) {
	const normalized = value.replace(/\+/g, " ");
	try {
		return decodeURIComponent(normalized);
	} catch {
		return value;
	}
}

window.addEventListener("message", (e) => {
	if (e.source != window.parent) return;
	const str = "" + e.data;
	if (str.startsWith("output:")) {
		const part = str.substring(7);
		const bits = part.split(/[&;]/g).map(decodeOutputPart);
		const fun = byond.outputtarget[bits[0]];
		if (typeof fun == "function") {
			fun(...bits.slice(1));
		}
	} else if (str.startsWith("callback:")) {
		const { callback, data }: { callback: string; data: string } = JSON.parse(
			str.substring(str.indexOf(":") + 1),
		);
		const callbackFn = resolveCallback(callback);
		if (typeof callbackFn === "function") {
			callbackFn(JSON.parse(data));
		}
	}
});

window.addEventListener("click", (e) => {
	const link = (e.target as HTMLElement).closest("a");
	if (link && !e.defaultPrevented) {
		e.preventDefault();
		byond.go(link.href);
	}
});

window.addEventListener("submit", (e) => {
	if (!e.defaultPrevented) {
		const form = (e.target as HTMLElement).closest("form");
		if (!form) return;
		const data = new FormData(form);
		const params = new URLSearchParams(data as any);
		let href = form.action;
		if (href.includes("?")) {
			href = href.substring(0, href.indexOf("?"));
		}
		href += "?";
		href += params.toString();
		byond.go(href);
		e.preventDefault();
	}
});

const location_proxy = Object.create(window.location, {
	href: {
		get() {
			return window.location.href;
		},
		set(href: string) {
			byond.go(href);
		},
	},
});

Object.defineProperty(window, "__location_proxy", {
	get() {
		return location_proxy;
	},
	set(str: string) {
		byond.go(str);
	},
});
