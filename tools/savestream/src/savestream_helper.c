/* Civ13 stream save helper (64-bit process, prototype).
 *
 *   savestream_helper write <out_file>   receive records on stdin, write a stream file
 *   savestream_helper read <in_file>     serve GET/DIR queries for a stream file
 *   savestream_helper dump <in_file>     print every node as "path<TAB>wire token"
 *
 * The 32-bit call_ext shim (savestream_shim.c) spawns this program and talks
 * to it over its stdin/stdout. See savestream_format.h for the formats.
 * Everything the save holds in memory lives here, in a 64-bit address space,
 * instead of in Dream Daemon.
 */
#define _FILE_OFFSET_BITS 64
#include <errno.h>
#include <math.h>
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#include <windows.h>
#include <psapi.h>
#ifndef __MINGW32__
#define fseeko _fseeki64
#define ftello _ftelli64
#endif
#endif
#include "savestream_format.h"

/* ---------- small utilities ---------- */

typedef struct { char *p; size_t n, cap; } buf_t;

static void *xmalloc(size_t n) { void *p = malloc(n ? n : 1); if (!p) { fprintf(stderr, "savestream: out of memory\n"); exit(3); } return p; }
static void *xrealloc(void *q, size_t n) { void *p = realloc(q, n ? n : 1); if (!p) { fprintf(stderr, "savestream: out of memory\n"); exit(3); } return p; }
static char *xstrndup(const char *s, size_t n) { char *p = xmalloc(n + 1); memcpy(p, s, n); p[n] = 0; return p; }

static void buf_reserve(buf_t *b, size_t extra) {
	if (b->n + extra <= b->cap) return;
	size_t cap = b->cap ? b->cap : 256;
	while (cap < b->n + extra) cap *= 2;
	b->p = xrealloc(b->p, cap);
	b->cap = cap;
}
static void buf_put(buf_t *b, const void *d, size_t n) { buf_reserve(b, n); memcpy(b->p + b->n, d, n); b->n += n; }
static void buf_byte(buf_t *b, int c) { unsigned char ch = (unsigned char)c; buf_put(b, &ch, 1); }
static void buf_str(buf_t *b, const char *s) { buf_put(b, s, strlen(s)); }
static void buf_fmt(buf_t *b, const char *fmt, ...) {
	char tmp[512];
	va_list ap; va_start(ap, fmt);
	int n = vsnprintf(tmp, sizeof tmp, fmt, ap);
	va_end(ap);
	if (n > 0) buf_put(b, tmp, (size_t)n < sizeof tmp ? (size_t)n : sizeof tmp - 1);
}
static void buf_varint(buf_t *b, uint64_t v) { do { unsigned char c = v & 0x7f; v >>= 7; if (v) c |= 0x80; buf_byte(b, c); } while (v); }
static void buf_u32(buf_t *b, uint32_t v) { unsigned char c[4] = { v, v >> 8, v >> 16, v >> 24 }; buf_put(b, c, 4); }
static void buf_u64(buf_t *b, uint64_t v) { for (int i = 0; i < 8; i++) buf_byte(b, (int)(v >> (8 * i))); }

static uint64_t fnv1a(const unsigned char *d, size_t n, uint64_t h) { for (size_t i = 0; i < n; i++) { h ^= d[i]; h *= 1099511628211ULL; } return h; }

static long peak_rss_kb(void) {
#ifdef _WIN32
	PROCESS_MEMORY_COUNTERS pmc;
	if (GetProcessMemoryInfo(GetCurrentProcess(), &pmc, sizeof pmc)) return (long)(pmc.PeakWorkingSetSize / 1024);
	return -1;
#else
	/* VmHWM, not getrusage: ru_maxrss survives exec and would report the
	 * parent Dream Daemon's resident size at fork time. */
	FILE *f = fopen("/proc/self/status", "r");
	char line[256]; long kb = -1;
	if (!f) return -1;
	while (fgets(line, sizeof line, f)) if (strncmp(line, "VmHWM:", 6) == 0) { kb = strtol(line + 6, NULL, 10); break; }
	fclose(f);
	return kb;
#endif
}

/* ---------- value model ---------- */

typedef struct value value_t;
typedef struct item item_t;
struct value {
	char kind;          /* n f s p l d x */
	float f;
	char *s; size_t slen; /* s, p, x */
	item_t *items; size_t count; /* l */
	uint64_t blob;      /* d */
};
struct item { value_t key; int has_assoc; value_t assoc; };

static void value_free(value_t *v) {
	if (v->kind == 's' || v->kind == 'p' || v->kind == 'x') free(v->s);
	if (v->kind == 'l') {
		for (size_t i = 0; i < v->count; i++) { value_free(&v->items[i].key); if (v->items[i].has_assoc) value_free(&v->items[i].assoc); }
		free(v->items);
	}
	memset(v, 0, sizeof *v);
}

/* ---------- blobs (file data) ---------- */

typedef struct { uint64_t h1, h2, size, offset; char *params; } blob_t;
static blob_t *blobs; static size_t blob_count, blob_cap;
static size_t *blob_table; static size_t blob_table_cap; /* open addressing, holds id+1 */
static uint64_t blob_bytes_unique, blob_bytes_total, blob_refs;

static int b64val(int c) {
	if (c >= 'A' && c <= 'Z') return c - 'A';
	if (c >= 'a' && c <= 'z') return c - 'a' + 26;
	if (c >= '0' && c <= '9') return c - '0' + 52;
	if (c == '+') return 62;
	if (c == '/') return 63;
	return -1;
}
static void b64decode(const char *s, size_t n, buf_t *out) {
	uint32_t acc = 0; int bits = 0;
	for (size_t i = 0; i < n; i++) {
		int v = b64val((unsigned char)s[i]);
		if (v < 0) continue; /* whitespace, newlines and padding */
		acc = (acc << 6) | (uint32_t)v; bits += 6;
		if (bits >= 8) { bits -= 8; buf_byte(out, (int)((acc >> bits) & 0xff)); }
	}
}
static void b64encode(const unsigned char *d, size_t n, buf_t *out) {
	static const char *t = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
	size_t col = 0;
	for (size_t i = 0; i < n; i += 3) {
		uint32_t v = (uint32_t)d[i] << 16;
		if (i + 1 < n) v |= (uint32_t)d[i + 1] << 8;
		if (i + 2 < n) v |= d[i + 2];
		char q[4] = { t[(v >> 18) & 63], t[(v >> 12) & 63], i + 1 < n ? t[(v >> 6) & 63] : '=', i + 2 < n ? t[v & 63] : '=' };
		buf_put(out, q, 4);
		col += 4;
		if (col >= 76) { buf_byte(out, '\n'); col = 0; }
	}
	if (col) buf_byte(out, '\n');
}

/* ---------- writer state ---------- */

typedef struct { char *path; uint64_t off; uint64_t seq; } node_t;
static FILE *out_file; static uint64_t out_pos;
static char *out_path, *tmp_path;
static node_t *nodes; static size_t node_count, node_cap;
static uint64_t record_count, raw_values, write_errors;
static buf_t rec; /* scratch record buffer */

/* structural validation */
typedef struct { unsigned char *bits; size_t cap; } bitset_t;
static void bit_set(bitset_t *b, uint64_t i) {
	if (i / 8 >= b->cap) { size_t cap = b->cap ? b->cap : 1024; while (cap <= i / 8) cap *= 2; b->bits = xrealloc(b->bits, cap); memset(b->bits + b->cap, 0, cap - b->cap); b->cap = cap; }
	b->bits[i / 8] |= (unsigned char)(1u << (i % 8));
}
static int bit_get(const bitset_t *b, uint64_t i) { return i / 8 < b->cap && (b->bits[i / 8] >> (i % 8)) & 1; }
static bitset_t entries_defined, lists_defined;
typedef struct { uint64_t *v; size_t n, cap; } u64vec_t;
static void vec_push(u64vec_t *v, uint64_t x) { if (v->n == v->cap) { v->cap = v->cap ? v->cap * 2 : 1024; v->v = xrealloc(v->v, v->cap * sizeof *v->v); } v->v[v->n++] = x; }
static u64vec_t entry_refs, list_refs;
static uint64_t map_cells;

static void out_write(const void *d, size_t n) {
	if (n && fwrite(d, 1, n, out_file) != n) { write_errors++; }
	out_pos += n;
}

static uint64_t blob_intern(const char *params, size_t plen, const unsigned char *data, size_t size) {
	uint64_t h1 = fnv1a(data, size, 14695981039346656037ULL);
	uint64_t h2 = fnv1a(data, size, 0x9e3779b97f4a7c15ULL) ^ (uint64_t)size;
	blob_refs++; blob_bytes_total += size;
	if (blob_table_cap == 0 || (blob_count + 1) * 2 > blob_table_cap) {
		size_t cap = blob_table_cap ? blob_table_cap * 2 : 1024;
		size_t *t = xmalloc(cap * sizeof *t); memset(t, 0, cap * sizeof *t);
		for (size_t i = 0; i < blob_count; i++) { size_t j = blobs[i].h1 & (cap - 1); while (t[j]) j = (j + 1) & (cap - 1); t[j] = i + 1; }
		free(blob_table); blob_table = t; blob_table_cap = cap;
	}
	size_t j = h1 & (blob_table_cap - 1);
	while (blob_table[j]) {
		blob_t *b = &blobs[blob_table[j] - 1];
		if (b->h1 == h1 && b->h2 == h2 && b->size == size) return blob_table[j] - 1;
		j = (j + 1) & (blob_table_cap - 1);
	}
	if (blob_count == blob_cap) { blob_cap = blob_cap ? blob_cap * 2 : 64; blobs = xrealloc(blobs, blob_cap * sizeof *blobs); }
	uint64_t id = blob_count++;
	blobs[id].h1 = h1; blobs[id].h2 = h2; blobs[id].size = size; blobs[id].offset = out_pos;
	blobs[id].params = xstrndup(params, plen);
	blob_table[j] = id + 1;
	blob_bytes_unique += size;
	buf_t b = {0};
	buf_byte(&b, 'B'); buf_varint(&b, id); buf_varint(&b, plen); buf_put(&b, params, plen); buf_varint(&b, size); buf_put(&b, data, size);
	out_write(b.p, b.n); free(b.p);
	return id;
}

/* ---------- savefile text parser ---------- */

typedef struct { const char *p, *end; char err[160]; } cursor_t;
static int fail(cursor_t *c, const char *msg) { if (!c->err[0]) snprintf(c->err, sizeof c->err, "%s near '%.24s'", msg, c->p < c->end ? c->p : ""); return 0; }
static void skip_ws(cursor_t *c) { while (c->p < c->end && (*c->p == ' ' || *c->p == '\t' || *c->p == '\r' || *c->p == '\n')) c->p++; }
static int starts(cursor_t *c, const char *s) { size_t n = strlen(s); return (size_t)(c->end - c->p) >= n && memcmp(c->p, s, n) == 0; }

/* Skip one balanced raw value: parentheses, "strings" and {"blocks"}. */
static int skip_raw(cursor_t *c) {
	int depth = 0;
	while (c->p < c->end) {
		char ch = *c->p;
		if (ch == '{' && c->p + 1 < c->end && c->p[1] == '"') {
			const char *e = c->p + 2;
			while (e + 1 < c->end && !(e[0] == '"' && e[1] == '}')) e++;
			if (e + 1 >= c->end) return fail(c, "unterminated {\" block");
			c->p = e + 2; continue;
		}
		if (ch == '"') {
			c->p++;
			while (c->p < c->end && *c->p != '"') { if (*c->p == '\\') c->p++; c->p++; }
			if (c->p >= c->end) return fail(c, "unterminated string");
			c->p++; continue;
		}
		if (ch == '(') depth++;
		else if (ch == ')') { if (depth == 0) return 1; if (--depth == 0) { c->p++; return 1; } }
		else if ((ch == ',' || ch == '\n' || ch == '=') && depth == 0) return 1;
		c->p++;
	}
	return depth == 0 ? 1 : fail(c, "unbalanced raw value");
}

static int parse_sf_value(cursor_t *c, value_t *v);

static int parse_sf_string(cursor_t *c, value_t *v) {
	buf_t b = {0};
	c->p++;
	while (c->p < c->end && *c->p != '"') {
		char ch = *c->p++;
		if (ch == '\\' && c->p < c->end) {
			char e = *c->p++;
			switch (e) {
			case 'n': buf_byte(&b, '\n'); break;
			case 't': buf_byte(&b, '\t'); break;
			default: buf_byte(&b, e); break; /* \" \\ \[ \] and anything else literal */
			}
		} else buf_byte(&b, ch);
	}
	if (c->p >= c->end) { free(b.p); return fail(c, "unterminated string"); }
	c->p++;
	buf_byte(&b, 0);
	v->kind = 's'; v->s = b.p; v->slen = b.n - 1;
	return 1;
}

static int parse_sf_filedata(cursor_t *c, value_t *v) {
	c->p += strlen("filedata(");
	skip_ws(c);
	if (c->p >= c->end || *c->p != '"') return fail(c, "filedata params");
	const char *ps = ++c->p;
	while (c->p < c->end && *c->p != '"') c->p++;
	const char *pe = c->p++;
	skip_ws(c);
	if (c->p >= c->end || *c->p != ',') return fail(c, "filedata comma");
	c->p++; skip_ws(c);
	if (!starts(c, "{\"")) return fail(c, "filedata block");
	const char *ds = c->p + 2, *de = ds;
	while (de + 1 < c->end && !(de[0] == '"' && de[1] == '}')) de++;
	if (de + 1 >= c->end) return fail(c, "unterminated filedata");
	c->p = de + 2; skip_ws(c);
	if (c->p >= c->end || *c->p != ')') return fail(c, "filedata close");
	c->p++;
	/* Only base64 encodings are produced by BYOND's exporter. */
	buf_t data = {0};
	b64decode(ds, (size_t)(de - ds), &data);
	v->kind = 'd';
	v->blob = blob_intern(ps, (size_t)(pe - ps), (unsigned char *)data.p, data.n);
	free(data.p);
	return 1;
}

static int parse_sf_value(cursor_t *c, value_t *v) {
	memset(v, 0, sizeof *v);
	skip_ws(c);
	if (c->p >= c->end) return fail(c, "missing value");
	char ch = *c->p;
	if (starts(c, "null") && (c->end - c->p == 4 || strchr(",)\n= \t\r", c->p[4]))) { c->p += 4; v->kind = 'n'; return 1; }
	if (ch == '"') return parse_sf_string(c, v);
	if (ch == '/') {
		const char *s = c->p;
		while (c->p < c->end && !strchr(",)\n= \t\r", *c->p)) c->p++;
		v->kind = 'p'; v->s = xstrndup(s, (size_t)(c->p - s)); v->slen = (size_t)(c->p - s); return 1;
	}
	if (ch == '-' || ch == '.' || (ch >= '0' && ch <= '9') || starts(c, "inf") || starts(c, "nan")) {
		char tmp[96]; const char *s = c->p;
		while (c->p < c->end && !strchr(",)\n= \t\r", *c->p)) c->p++;
		size_t n = (size_t)(c->p - s); if (n >= sizeof tmp) return fail(c, "number too long");
		memcpy(tmp, s, n); tmp[n] = 0;
		char *endp; double d = strtod(tmp, &endp);
		if (*endp) return fail(c, "bad number");
		v->kind = 'f'; v->f = (float)d; return 1;
	}
	if (starts(c, "list(")) {
		c->p += 5;
		v->kind = 'l';
		size_t cap = 0;
		skip_ws(c);
		if (c->p < c->end && *c->p == ')') { c->p++; return 1; }
		for (;;) {
			if (v->count == cap) { cap = cap ? cap * 2 : 4; v->items = xrealloc(v->items, cap * sizeof *v->items); }
			item_t *it = &v->items[v->count]; memset(it, 0, sizeof *it);
			if (!parse_sf_value(c, &it->key)) return 0;
			v->count++;
			skip_ws(c);
			if (c->p < c->end && *c->p == '=') { c->p++; it->has_assoc = 1; if (!parse_sf_value(c, &it->assoc)) return 0; skip_ws(c); }
			if (c->p < c->end && *c->p == ',') { c->p++; continue; }
			if (c->p < c->end && *c->p == ')') { c->p++; return 1; }
			return fail(c, "list separator");
		}
	}
	if (starts(c, "filedata(")) return parse_sf_filedata(c, v);
	/* appearance(...), object(".0"), newlist(...) and anything unknown */
	const char *s = c->p;
	if (!skip_raw(c)) return 0;
	v->kind = 'x'; v->slen = (size_t)(c->p - s); v->s = xstrndup(s, v->slen);
	raw_values++;
	return 1;
}

/* ---------- wire tokens ---------- */

static int read_len(cursor_t *c, char term, size_t *out) {
	size_t n = 0; int digits = 0;
	while (c->p < c->end && *c->p >= '0' && *c->p <= '9') { n = n * 10 + (size_t)(*c->p - '0'); c->p++; digits++; }
	if (!digits || c->p >= c->end || *c->p != term) return fail(c, "bad length");
	c->p++;
	if ((size_t)(c->end - c->p) < n && term == ':') return fail(c, "truncated token");
	*out = n; return 1;
}

static int parse_wire(cursor_t *c, value_t *v) {
	memset(v, 0, sizeof *v);
	if (c->p >= c->end) return fail(c, "missing token");
	char t = *c->p++;
	size_t n;
	switch (t) {
	case 'N': v->kind = 'n'; return 1;
	case 'F': {
		const char *s = c->p;
		while (c->p < c->end && *c->p != ';') c->p++;
		if (c->p >= c->end) return fail(c, "bad number token");
		char tmp[96]; size_t len = (size_t)(c->p - s); if (len >= sizeof tmp) return fail(c, "number too long");
		memcpy(tmp, s, len); tmp[len] = 0; c->p++;
		char *endp; double d = strtod(tmp, &endp);
		if (*endp) return fail(c, "bad number");
		v->kind = 'f'; v->f = (float)d; return 1;
	}
	case 'S': case 'P':
		if (!read_len(c, ':', &n)) return 0;
		v->kind = t == 'S' ? 's' : 'p'; v->s = xstrndup(c->p, n); v->slen = n; c->p += n; return 1;
	case 'Y': {
		/* A one-node BYOND savefile the game wrote for a value whose savefile
		 * text does not import back (mutable appearances). Stored as a blob;
		 * the file is removed once read. */
		if (!read_len(c, ':', &n)) return 0;
		char *fpath = xstrndup(c->p, n);
		c->p += n;
		FILE *f = fopen(fpath, "rb");
		if (!f) { free(fpath); return fail(c, "cannot open value file"); }
		buf_t data = {0}; char chunk[65536]; size_t got;
		while ((got = fread(chunk, 1, sizeof chunk, f)) > 0) buf_put(&data, chunk, got);
		fclose(f);
		remove(fpath);
		free(fpath);
		v->kind = 'y';
		v->blob = blob_intern("savefile", 8, (unsigned char *)data.p, data.n);
		free(data.p);
		return 1;
	}
	case 'X': {
		if (!read_len(c, ':', &n)) return 0;
		cursor_t sub = { c->p, c->p + n, {0} };
		c->p += n;
		if (!parse_sf_value(&sub, v)) { snprintf(c->err, sizeof c->err, "%s", sub.err); return 0; }
		skip_ws(&sub);
		if (sub.p < sub.end) {
			/* Child lines (saved objects): keep the whole text raw. */
			value_free(v);
			v->kind = 'x'; v->s = xstrndup(sub.end - n, n); v->slen = n; raw_values++;
		}
		return 1;
	}
	case 'L': {
		if (!read_len(c, ';', &n)) return 0;
		v->kind = 'l'; v->count = 0;
		v->items = n ? xmalloc(n * sizeof *v->items) : NULL;
		for (size_t i = 0; i < n; i++) {
			item_t *it = &v->items[i]; memset(it, 0, sizeof *it);
			if (!parse_wire(c, &it->key)) return 0;
			v->count++;
			if (c->p >= c->end) return fail(c, "truncated list");
			if (*c->p == '=') { c->p++; it->has_assoc = 1; if (!parse_wire(c, &it->assoc)) return 0; }
			else if (*c->p == '.') c->p++;
			else return fail(c, "bad list item");
		}
		return 1;
	}
	}
	c->p--;
	return fail(c, "unknown token");
}

static void emit_value_bin(buf_t *b, const value_t *v) {
	buf_byte(b, v->kind);
	switch (v->kind) {
	case 'f': { uint32_t u; memcpy(&u, &v->f, 4); buf_u32(b, u); break; }
	case 's': case 'p': case 'x': buf_varint(b, v->slen); buf_put(b, v->s, v->slen); break;
	case 'd': case 'y': buf_varint(b, v->blob); break;
	case 'l':
		buf_varint(b, v->count);
		for (size_t i = 0; i < v->count; i++) {
			emit_value_bin(b, &v->items[i].key);
			buf_byte(b, v->items[i].has_assoc);
			if (v->items[i].has_assoc) emit_value_bin(b, &v->items[i].assoc);
		}
		break;
	}
}

/* ---------- structural validation ---------- */

static const value_t *assoc_of(const value_t *list, const char *key) {
	for (size_t i = 0; i < list->count; i++) {
		const item_t *it = &list->items[i];
		if (it->has_assoc && it->key.kind == 's' && it->key.slen == strlen(key) && memcmp(it->key.s, key, it->key.slen) == 0) return &it->assoc;
	}
	return NULL;
}
static void scan_refs(const value_t *v) {
	if (v->kind != 'l') return;
	const value_t *kind = assoc_of(v, "kind"), *ref = assoc_of(v, "ref");
	if (kind && ref && kind->kind == 's' && ref->kind == 'f' && ref->f > 0) {
		if (kind->slen == 5 && memcmp(kind->s, "entry", 5) == 0) vec_push(&entry_refs, (uint64_t)ref->f);
		else if (kind->slen == 4 && memcmp(kind->s, "list", 4) == 0) vec_push(&list_refs, (uint64_t)ref->f);
	}
	for (size_t i = 0; i < v->count; i++) { scan_refs(&v->items[i].key); if (v->items[i].has_assoc) scan_refs(&v->items[i].assoc); }
}
static int path_parts(const char *path, const char **parts, size_t *lens, int max) {
	int n = 0; const char *p = path;
	while (*p == '/') p++;
	while (*p && n < max) { const char *s = p; while (*p && *p != '/') p++; parts[n] = s; lens[n] = (size_t)(p - s); n++; while (*p == '/') p++; }
	return *p ? max + 1 : n;
}
static int part_is(const char *s, size_t n, const char *lit) { return n == strlen(lit) && memcmp(s, lit, n) == 0; }
static void track(const char *path, const value_t *v) {
	const char *parts[6]; size_t lens[6];
	int n = path_parts(path, parts, lens, 5);
	if (n == 4 && part_is(parts[0], lens[0], "entries") && part_is(parts[3], lens[3], "type")) bit_set(&entries_defined, strtoull(parts[2], NULL, 10));
	else if (n == 3 && part_is(parts[0], lens[0], "lists") && part_is(parts[2], lens[2], "length")) bit_set(&lists_defined, strtoull(parts[1], NULL, 10));
	/* Value format 2: an all-scalar list is the single node /lists/<id>. */
	else if (n == 2 && part_is(parts[0], lens[0], "lists")) bit_set(&lists_defined, strtoull(parts[1], NULL, 10));
	else if (n == 4 && part_is(parts[0], lens[0], "map")) { map_cells++; if (v->kind == 'f' && v->f > 0) vec_push(&entry_refs, (uint64_t)v->f); }
	scan_refs(v);
}

/* ---------- write mode ---------- */

static void close_write_reader(void);

static void add_node(const char *path, size_t plen, uint64_t off) {
	if (node_count == node_cap) { node_cap = node_cap ? node_cap * 2 : 4096; nodes = xrealloc(nodes, node_cap * sizeof *nodes); }
	nodes[node_count].path = xstrndup(path, plen); nodes[node_count].off = off; nodes[node_count].seq = node_count; node_count++;
}

static int write_record(const char *path, size_t plen, value_t *v) {
	char *p0 = xstrndup(path, plen);
	track(p0, v);
	free(p0);
	rec.n = 0;
	buf_byte(&rec, 'V');
	uint64_t value_off = out_pos + rec.n;
	emit_value_bin(&rec, v);
	out_write(rec.p, rec.n);
	add_node(path, plen, value_off);
	record_count++;
	return 1;
}

/* Batch: W<len>:<path> <token>  or  T<len>:<base path>|<savefile text subtree> */
static int write_subtree(const char *base, size_t blen, const char *text, size_t tlen, char *err, size_t errlen);

static int handle_write(const char *d, size_t n, char *err, size_t errlen) {
	cursor_t c = { d, d + n, {0} };
	while (c.p < c.end) {
		char t = *c.p++;
		size_t len;
		if (t == 'W') {
			if (!read_len(&c, ':', &len)) break;
			const char *path = c.p; c.p += len;
			if (!len || path[0] != '/') { fail(&c, "path must be absolute"); break; }
			value_t v;
			if (!parse_wire(&c, &v)) { value_free(&v); break; }
			write_record(path, len, &v);
			value_free(&v);
		} else if (t == 'T') {
			if (!read_len(&c, ':', &len)) break;
			const char *body = c.p; c.p += len;
			const char *bar = memchr(body, '|', len);
			if (!bar) { fail(&c, "subtree without base"); break; }
			if (!write_subtree(body, (size_t)(bar - body), bar + 1, len - (size_t)(bar - body) - 1, c.err, sizeof c.err)) break;
		} else { c.p--; fail(&c, "unknown record"); break; }
	}
	if (c.err[0]) { snprintf(err, errlen, "%s", c.err); return 0; }
	return 1;
}

/* Parse BYOND savefile text (ExportText of a node) into records. */
static int write_subtree(const char *base, size_t blen, const char *text, size_t tlen, char *err, size_t errlen) {
	cursor_t c = { text, text + tlen, {0} };
	char *stack[64]; int depth = 0;
	buf_t path = {0};
	int ok = 1;
	while (c.p < c.end && ok) {
		int indent = 0;
		while (c.p < c.end && *c.p == '\t') { c.p++; indent++; }
		if (c.p >= c.end) break;
		if (*c.p == '\n' || *c.p == '\r') { c.p++; continue; }
		const char *ns = c.p;
		if (*c.p == '"') { c.p++; while (c.p < c.end && *c.p != '"') { if (*c.p == '\\') c.p++; c.p++; } c.p++; }
		else while (c.p < c.end && *c.p != '\n' && !(c.p[0] == ' ' && c.p + 2 < c.end && c.p[1] == '=' && c.p[2] == ' ')) c.p++;
		const char *ne = c.p;
		if (indent > depth || indent >= 63) { snprintf(err, errlen, "bad indent in subtree"); ok = 0; break; }
		for (int i = indent; i < depth; i++) free(stack[i]);
		depth = indent;
		stack[depth++] = xstrndup(ns, (size_t)(ne - ns));
		path.n = 0; buf_put(&path, base, blen);
		int self = (ne - ns == 1 && *ns == '.' && indent == 0);
		if (!self) for (int i = 0; i < depth; i++) { buf_byte(&path, '/'); buf_str(&path, stack[i]); }
		if (self) depth = 0, free(stack[0]);
		if (c.p < c.end && *c.p == ' ') {
			c.p += 3; /* " = " */
			value_t v; const char *vs = c.p;
			if (!parse_sf_value(&c, &v)) { snprintf(err, errlen, "%s", c.err); value_free(&v); ok = 0; break; }
			/* A saved object's fields follow as deeper lines; keep them raw with the value. */
			const char *after = c.p; while (after < c.end && *after == '\r') after++;
			if (after < c.end && *after == '\n') {
				const char *q = after + 1; int child = 0;
				while (q < c.end) {
					int ind = 0; const char *r = q; while (r < c.end && *r == '\t') { r++; ind++; }
					if (ind <= indent || r >= c.end || *r == '\n') break;
					child = 1;
					while (q < c.end && *q != '\n') q++;
					if (q < c.end) q++;
				}
				if (child) {
					buf_t raw = {0};
					buf_put(&raw, vs, (size_t)(c.p - vs)); buf_byte(&raw, '\n');
					const char *r = after + 1;
					while (r < q) { int skip = 0; while (r < q && *r == '\t' && skip < indent + 1) { r++; skip++; } while (r < q && *r != '\n') buf_byte(&raw, *r++); if (r < q) { buf_byte(&raw, '\n'); r++; } }
					value_free(&v); v.kind = 'x'; v.s = raw.p; v.slen = raw.n; raw_values++;
					write_record(path.p, path.n, &v);
					value_free(&v);
					c.p = q; /* already at the start of the next sibling line */
					continue;
				}
			}
			write_record(path.p, path.n, &v);
			value_free(&v);
		}
		while (c.p < c.end && *c.p != '\n') c.p++;
		if (c.p < c.end) c.p++;
	}
	for (int i = 0; i < depth; i++) free(stack[i]);
	free(path.p);
	return ok;
}

static int cmp_node(const void *a, const void *b) {
	const node_t *x = a, *y = b;
	int r = strcmp(x->path, y->path);
	if (r) return r;
	return x->seq < y->seq ? -1 : x->seq > y->seq;
}
static int cmp_u64(const void *a, const void *b) { uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b; return x < y ? -1 : x > y; }

static void finish_write(int force, buf_t *reply) {
	qsort(nodes, node_count, sizeof *nodes, cmp_node);
	size_t unique = 0;
	for (size_t i = 0; i < node_count; i++) {
		if (unique && strcmp(nodes[unique - 1].path, nodes[i].path) == 0) { free(nodes[unique - 1].path); nodes[unique - 1] = nodes[i]; }
		else nodes[unique++] = nodes[i];
	}
	node_count = unique;
	uint64_t missing_entries = 0, missing_lists = 0, first_missing_entry = 0, first_missing_list = 0;
	for (size_t i = 0; i < entry_refs.n; i++) if (!bit_get(&entries_defined, entry_refs.v[i])) { if (!missing_entries++) first_missing_entry = entry_refs.v[i]; }
	for (size_t i = 0; i < list_refs.n; i++) if (!bit_get(&lists_defined, list_refs.v[i])) { if (!missing_lists++) first_missing_list = list_refs.v[i]; }
	uint64_t index_off = out_pos;
	buf_t b = {0};
	buf_varint(&b, node_count);
	const char *prev = "";
	for (size_t i = 0; i < node_count; i++) {
		/* Front coding: sorted paths share long prefixes. */
		const char *path = nodes[i].path;
		size_t shared = 0;
		while (prev[shared] && prev[shared] == path[shared]) shared++;
		size_t rest = strlen(path + shared);
		buf_varint(&b, shared); buf_varint(&b, rest); buf_put(&b, path + shared, rest); buf_varint(&b, nodes[i].off);
		prev = path;
		if (b.n > (1u << 20)) { out_write(b.p, b.n); b.n = 0; }
	}
	buf_varint(&b, blob_count);
	for (size_t i = 0; i < blob_count; i++) buf_u64(&b, blobs[i].offset);
	buf_u64(&b, index_off); buf_u64(&b, node_count); buf_put(&b, SAVESTREAM_INDEX_MAGIC, 8);
	out_write(b.p, b.n); free(b.p);
	close_write_reader();
	int valid = missing_entries == 0 && missing_lists == 0 && write_errors == 0;
	int io_ok = fflush(out_file) == 0 && write_errors == 0;
	io_ok = (fclose(out_file) == 0) && io_ok;
	out_file = NULL;
	int published = 0;
	if (io_ok && (valid || force)) {
		remove(out_path);
		published = rename(tmp_path, out_path) == 0;
	}
	(void)cmp_u64;
	buf_fmt(reply, "{\"ok\":%s,\"published\":%s,\"valid\":%s,\"nodes\":%llu,\"records\":%llu,\"bytes\":%llu,",
		published ? "true" : "false", published ? "true" : "false", valid ? "true" : "false",
		(unsigned long long)node_count, (unsigned long long)record_count, (unsigned long long)out_pos);
	buf_fmt(reply, "\"blobs\":%llu,\"blob_refs\":%llu,\"blob_bytes_unique\":%llu,\"blob_bytes_total\":%llu,\"raw_values\":%llu,",
		(unsigned long long)blob_count, (unsigned long long)blob_refs, (unsigned long long)blob_bytes_unique, (unsigned long long)blob_bytes_total, (unsigned long long)raw_values);
	buf_fmt(reply, "\"map_cells\":%llu,\"entry_refs\":%llu,\"missing_entry_refs\":%llu,\"first_missing_entry\":%llu,\"list_refs\":%llu,\"missing_lists\":%llu,\"first_missing_list\":%llu,\"helper_peak_rss_kb\":%ld}",
		(unsigned long long)map_cells, (unsigned long long)entry_refs.n, (unsigned long long)missing_entries, (unsigned long long)first_missing_entry,
		(unsigned long long)list_refs.n, (unsigned long long)missing_lists, (unsigned long long)first_missing_list, peak_rss_kb());
}

/* ---------- read mode ---------- */

static FILE *in_file;
static const char *in_path;
static uint64_t value_files;
static char **rpaths; static uint64_t *roffs; static uint64_t rcount;
static uint64_t *rblob_offs; static uint64_t rblob_count;

static int rd_byte(FILE *f) { return fgetc(f); }
static int rd_varint(FILE *f, uint64_t *v) { uint64_t r = 0; int shift = 0, c; do { c = fgetc(f); if (c == EOF || shift > 63) return 0; r |= (uint64_t)(c & 0x7f) << shift; shift += 7; } while (c & 0x80); *v = r; return 1; }
static int rd_u64(FILE *f, uint64_t *v) { unsigned char c[8]; if (fread(c, 1, 8, f) != 8) return 0; uint64_t r = 0; for (int i = 7; i >= 0; i--) r = (r << 8) | c[i]; *v = r; return 1; }

static int open_reader(const char *path, char *err, size_t errlen) {
	in_file = fopen(path, "rb");
	if (!in_file) { snprintf(err, errlen, "cannot open %s: %s", path, strerror(errno)); return 0; }
	char magic[8];
	if (fread(magic, 1, 8, in_file) != 8 || memcmp(magic, SAVESTREAM_MAGIC, 8) != 0) { snprintf(err, errlen, "not a stream save"); return 0; }
	if (fseeko(in_file, -24, SEEK_END) != 0) { snprintf(err, errlen, "short file"); return 0; }
	uint64_t index_off, count; char imagic[8];
	if (!rd_u64(in_file, &index_off) || !rd_u64(in_file, &count) || fread(imagic, 1, 8, in_file) != 8 || memcmp(imagic, SAVESTREAM_INDEX_MAGIC, 8) != 0) { snprintf(err, errlen, "missing index (incomplete file)"); return 0; }
	fseeko(in_file, (int64_t)index_off, SEEK_SET);
	uint64_t n;
	if (!rd_varint(in_file, &n) || n != count) { snprintf(err, errlen, "index count mismatch"); return 0; }
	rpaths = xmalloc((size_t)n * sizeof *rpaths); roffs = xmalloc((size_t)n * sizeof *roffs);
	for (uint64_t i = 0; i < n; i++) {
		uint64_t shared, rest;
		if (!rd_varint(in_file, &shared) || !rd_varint(in_file, &rest) || rest > (1u << 20) || (shared && (i == 0 || shared > strlen(rpaths[i - 1])))) { snprintf(err, errlen, "bad index entry"); return 0; }
		rpaths[i] = xmalloc((size_t)(shared + rest) + 1);
		if (shared) memcpy(rpaths[i], rpaths[i - 1], (size_t)shared);
		if (fread(rpaths[i] + shared, 1, (size_t)rest, in_file) != rest || !rd_varint(in_file, &roffs[i])) { snprintf(err, errlen, "truncated index"); return 0; }
		rpaths[i][shared + rest] = 0;
	}
	rcount = n;
	if (!rd_varint(in_file, &rblob_count)) { snprintf(err, errlen, "truncated blob table"); return 0; }
	rblob_offs = xmalloc((size_t)rblob_count * sizeof *rblob_offs);
	for (uint64_t i = 0; i < rblob_count; i++) if (!rd_u64(in_file, &rblob_offs[i])) { snprintf(err, errlen, "truncated blob table"); return 0; }
	return 1;
}

static int64_t find_path(const char *path) {
	int64_t lo = 0, hi = (int64_t)rcount - 1;
	while (lo <= hi) { int64_t mid = (lo + hi) / 2; int r = strcmp(rpaths[mid], path); if (!r) return mid; if (r < 0) lo = mid + 1; else hi = mid - 1; }
	return -1;
}

static void emit_wire_string(buf_t *b, char t, const char *s, size_t n) { buf_fmt(b, "%c%llu:", t, (unsigned long long)n); buf_put(b, s, n); }

/* filedata("params",{"base64"}): BYOND savefile text for a stored blob. */
static int blob_text(buf_t *t, uint64_t id) {
	if (id >= rblob_count) return 0;
	int64_t save = ftello(in_file);
	fseeko(in_file, (int64_t)rblob_offs[id], SEEK_SET);
	uint64_t bid, plen, size;
	if (rd_byte(in_file) != 'B' || !rd_varint(in_file, &bid) || bid != id || !rd_varint(in_file, &plen)) return 0;
	char *params = xmalloc((size_t)plen + 1);
	if (fread(params, 1, (size_t)plen, in_file) != plen) { free(params); return 0; }
	params[plen] = 0;
	if (!rd_varint(in_file, &size)) { free(params); return 0; }
	unsigned char *data = xmalloc((size_t)size);
	if (fread(data, 1, (size_t)size, in_file) != size) { free(params); free(data); return 0; }
	buf_str(t, "filedata(\""); buf_put(t, params, (size_t)plen); buf_str(t, "\",{\"\n");
	b64encode(data, (size_t)size, t);
	buf_str(t, "\"})");
	free(params); free(data);
	fseeko(in_file, save, SEEK_SET);
	return 1;
}

static int emit_blob_text(buf_t *b, uint64_t id) {
	buf_t t = {0};
	int ok = blob_text(&t, id);
	if (ok) emit_wire_string(b, 'X', t.p, t.n);
	free(t.p);
	return ok;
}

/* Write a stored one-node savefile next to the stream for the game to read
 * (and delete). */
static int emit_value_file(buf_t *b, uint64_t id) {
	if (id >= rblob_count) return 0;
	int64_t save = ftello(in_file);
	fseeko(in_file, (int64_t)rblob_offs[id], SEEK_SET);
	uint64_t bid, plen, size;
	if (rd_byte(in_file) != 'B' || !rd_varint(in_file, &bid) || bid != id || !rd_varint(in_file, &plen)) return 0;
	fseeko(in_file, (int64_t)plen, SEEK_CUR);
	if (!rd_varint(in_file, &size)) return 0;
	unsigned char *data = xmalloc((size_t)size);
	if (fread(data, 1, (size_t)size, in_file) != size) { free(data); return 0; }
	char name[1024];
	snprintf(name, sizeof name, "%s.value%llu.sav", in_path, (unsigned long long)++value_files);
	FILE *f = fopen(name, "wb");
	int ok = f && fwrite(data, 1, (size_t)size, f) == size;
	if (f) ok = (fclose(f) == 0) && ok;
	free(data);
	fseeko(in_file, save, SEEK_SET);
	if (!ok) return 0;
	emit_wire_string(b, 'Y', name, strlen(name));
	return 1;
}

/* Decode one binary value at the current position into a wire token. */
static int emit_value_wire(buf_t *b) {
	int k = rd_byte(in_file);
	uint64_t n;
	switch (k) {
	case 'n': buf_byte(b, 'N'); return 1;
	case 'f': {
		unsigned char c[4]; if (fread(c, 1, 4, in_file) != 4) return 0;
		uint32_t u = c[0] | (uint32_t)c[1] << 8 | (uint32_t)c[2] << 16 | (uint32_t)c[3] << 24; float f; memcpy(&f, &u, 4);
		if (isnan(f)) buf_str(b, "Fnan;");
		else if (isinf(f)) buf_str(b, f > 0 ? "Finf;" : "F-inf;");
		else buf_fmt(b, "F%.9g;", (double)f);
		return 1;
	}
	case 's': case 'p': case 'x': {
		if (!rd_varint(in_file, &n)) return 0;
		char *s = xmalloc((size_t)n + 1);
		if (fread(s, 1, (size_t)n, in_file) != n) { free(s); return 0; }
		emit_wire_string(b, k == 's' ? 'S' : k == 'p' ? 'P' : 'X', s, (size_t)n);
		free(s); return 1;
	}
	case 'd': if (!rd_varint(in_file, &n)) return 0; return emit_blob_text(b, n);
	case 'y': if (!rd_varint(in_file, &n)) return 0; return emit_value_file(b, n);
	case 'l':
		if (!rd_varint(in_file, &n)) return 0;
		buf_fmt(b, "L%llu;", (unsigned long long)n);
		for (uint64_t i = 0; i < n; i++) {
			if (!emit_value_wire(b)) return 0;
			int has = rd_byte(in_file);
			if (has == 1) { buf_byte(b, '='); if (!emit_value_wire(b)) return 0; }
			else if (has == 0) buf_byte(b, '.');
			else return 0;
		}
		return 1;
	}
	return 0;
}

static int get_value(const char *path, buf_t *reply) {
	int64_t i = find_path(path);
	if (i < 0) { buf_byte(reply, '?'); return 1; }
	fseeko(in_file, (int64_t)roffs[i], SEEK_SET);
	return emit_value_wire(reply);
}

static void dir_value(const char *path, buf_t *reply) {
	size_t plen = strlen(path);
	while (plen && path[plen - 1] == '/') plen--;
	char *prefix = xmalloc(plen + 2); memcpy(prefix, path, plen); prefix[plen] = '/'; prefix[plen + 1] = 0;
	/* lower bound of prefix */
	int64_t lo = 0, hi = (int64_t)rcount;
	while (lo < hi) { int64_t mid = (lo + hi) / 2; if (strcmp(rpaths[mid], prefix) < 0) lo = mid + 1; else hi = mid; }
	buf_t names = {0}; uint64_t count = 0;
	const char *last = NULL; size_t last_len = 0;
	char **seen = NULL; size_t seen_n = 0, seen_cap = 0;
	for (int64_t i = lo; i < (int64_t)rcount && strncmp(rpaths[i], prefix, plen + 1) == 0; i++) {
		const char *s = rpaths[i] + plen + 1; const char *e = strchr(s, '/'); size_t n = e ? (size_t)(e - s) : strlen(s);
		if (last && last_len == n && memcmp(last, s, n) == 0) continue;
		int dup = 0;
		for (size_t j = seen_n > 64 ? seen_n - 64 : 0; j < seen_n; j++) if (strlen(seen[j]) == n && memcmp(seen[j], s, n) == 0) { dup = 1; break; }
		last = s; last_len = n;
		if (dup) continue;
		if (seen_n == seen_cap) { seen_cap = seen_cap ? seen_cap * 2 : 64; seen = xrealloc(seen, seen_cap * sizeof *seen); }
		seen[seen_n++] = xstrndup(s, n);
		emit_wire_string(&names, 'S', s, n); buf_byte(&names, '.'); count++;
	}
	buf_fmt(reply, "L%llu;", (unsigned long long)count);
	buf_put(reply, names.p, names.n);
	for (size_t j = 0; j < seen_n; j++) free(seen[j]);
	free(seen); free(names.p); free(prefix);
}

/* Index position of the first node at or after path (read mode). */
static uint64_t seek_path(const char *path) {
	int64_t lo = 0, hi = (int64_t)rcount;
	while (lo < hi) { int64_t mid = (lo + hi) / 2; if (strcmp(rpaths[mid], path) < 0) lo = mid + 1; else hi = mid; }
	return (uint64_t)lo;
}

/* ---------- savefile text (OP_TEXT) ----------
 *
 * Renders a subtree as BYOND savefile text, relative to a base path, so the
 * game builds its scratch savefile with one native ImportText() call instead
 * of decoding every wire token in DM. Nodes whose value or name has no exact
 * text form (text macros, control characters, inf/nan, value files, objects
 * with child lines, odd node names) are left out of the text and listed for
 * the game to fetch one by one with OP_GET; their children still appear.
 *
 * Reply: "<n>;" then n x "W<len>:<absolute path>", then the text. */

/* 1 when written, 0 when the value has no exact text form, -1 when corrupt. */
static int value_text(buf_t *b) {
	int k = rd_byte(in_file);
	uint64_t n;
	switch (k) {
	case 'n': buf_str(b, "null"); return 1;
	case 'f': {
		unsigned char c[4]; if (fread(c, 1, 4, in_file) != 4) return -1;
		uint32_t u = c[0] | (uint32_t)c[1] << 8 | (uint32_t)c[2] << 16 | (uint32_t)c[3] << 24; float f; memcpy(&f, &u, 4);
		if (isnan(f) || isinf(f)) return 0;
		buf_fmt(b, "%.9g", (double)f);
		return 1;
	}
	case 's': case 'p': case 'x': {
		if (!rd_varint(in_file, &n)) return -1;
		char *v = xmalloc((size_t)n + 1);
		if (fread(v, 1, (size_t)n, in_file) != n) { free(v); return -1; }
		int ok = 1;
		if (k == 's') {
			for (uint64_t i = 0; i < n && ok; i++) { unsigned char ch = (unsigned char)v[i]; if (ch == 0xff || (ch < 0x20 && ch != '\n' && ch != '\t')) ok = 0; }
			if (ok) {
				buf_byte(b, '"');
				for (uint64_t i = 0; i < n; i++) {
					char ch = v[i];
					if (ch == '"' || ch == '\\' || ch == '[' || ch == ']') { buf_byte(b, '\\'); buf_byte(b, ch); }
					else if (ch == '\n') buf_str(b, "\\n");
					else buf_byte(b, ch);
				}
				buf_byte(b, '"');
			}
		} else if (k == 'p') {
			ok = n > 0 && v[0] == '/';
			for (uint64_t i = 0; i < n && ok; i++) { char ch = v[i]; if (!(ch == '/' || ch == '_' || (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z'))) ok = 0; }
			if (ok) buf_put(b, v, (size_t)n);
		} else {
			/* Raw savefile text: only a one-line value fits a nested line. */
			ok = n > 0 && !memchr(v, '\n', (size_t)n) && !memchr(v, '\r', (size_t)n);
			if (ok) buf_put(b, v, (size_t)n);
		}
		free(v);
		return ok;
	}
	case 'd': if (!rd_varint(in_file, &n)) return -1; return blob_text(b, n) ? 1 : -1;
	case 'y': return 0;
	case 'l': {
		if (!rd_varint(in_file, &n)) return -1;
		buf_str(b, "list(");
		for (uint64_t i = 0; i < n; i++) {
			if (i) buf_byte(b, ',');
			int r = value_text(b);
			if (r <= 0) return r;
			int has = rd_byte(in_file);
			if (has == 1) { buf_str(b, " = "); r = value_text(b); if (r <= 0) return r; }
			else if (has != 0) return -1;
		}
		buf_byte(b, ')');
		return 1;
	}
	}
	return -1;
}

typedef struct {
	buf_t text, missing;
	uint64_t missing_count, nodes;
	/* Directories open in the text, as components of the last emitted path. */
	char *open; size_t comp_start[64], comp_len[64]; int depth;
} textout_t;

static int name_ok(const char *s, size_t n) {
	if (!n) return 0;
	for (size_t i = 0; i < n; i++) { char ch = s[i]; if (!(ch == '_' || (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z'))) return 0; }
	return 1;
}

static void text_missing(textout_t *t, const char *path) { emit_wire_string(&t->missing, 'W', path, strlen(path)); t->missing_count++; }

/* One node; rel is its path below the base ("" for the base itself). */
static int text_node(textout_t *t, uint64_t i, const char *rel) {
	const char *path = rpaths[i];
	size_t start[64], len[64]; int n = 0;
	if (*rel) {
		const char *p = rel;
		while (*p == '/') {
			const char *s = p + 1, *e = strchr(s, '/');
			size_t l = e ? (size_t)(e - s) : strlen(s);
			if (n == 64 || !name_ok(s, l)) { text_missing(t, path); return 1; }
			start[n] = (size_t)(s - rel); len[n] = l; n++;
			p = s + l;
		}
		if (*p) { text_missing(t, path); return 1; }
	}
	/* Close directories the sorted order has left, open the ones above this node. */
	int common = 0;
	while (common < t->depth && common < n - 1 && t->comp_len[common] == len[common] && memcmp(t->open + t->comp_start[common], rel + start[common], len[common]) == 0) common++;
	for (int d = common; d < n - 1; d++) {
		for (int k = 0; k < d; k++) buf_byte(&t->text, '\t');
		buf_put(&t->text, rel + start[d], len[d]); buf_byte(&t->text, '\n');
	}
	free(t->open);
	t->open = xstrndup(rel, strlen(rel));
	for (int d = 0; d < n; d++) { t->comp_start[d] = start[d]; t->comp_len[d] = len[d]; }
	t->depth = n;
	size_t mark = t->text.n;
	for (int k = 0; k < n - 1; k++) buf_byte(&t->text, '\t');
	if (n) buf_put(&t->text, rel + start[n - 1], len[n - 1]); else buf_byte(&t->text, '.');
	size_t name_end = t->text.n;
	buf_str(&t->text, " = ");
	if (fseeko(in_file, (int64_t)roffs[i], SEEK_SET) != 0) return 0;
	int r = value_text(&t->text);
	if (r < 0) return 0;
	if (r == 0) {
		text_missing(t, path);
		t->text.n = n ? name_end : mark; /* keep the directory line for its children */
	}
	if (t->text.n > mark) buf_byte(&t->text, '\n');
	t->nodes++;
	return 1;
}

/* Every node at prefix or below it. */
static int text_subtree(textout_t *t, const char *base, const char *prefix) {
	size_t blen = strlen(base), plen = strlen(prefix);
	for (uint64_t i = seek_path(prefix); i < rcount; i++) {
		const char *p = rpaths[i];
		if (strncmp(p, prefix, plen) != 0 || (p[plen] && p[plen] != '/')) break;
		if (!text_node(t, i, p + blen)) return 0;
	}
	return 1;
}

/* payload: "<base>" or "<base>\n<first>\n<last>" (numeric children of base). */
static void text_value(const char *payload, buf_t *reply) {
	char *base = xstrndup(payload, strlen(payload));
	char *nl = strchr(base, '\n');
	unsigned long long first = 0, last = 0;
	int ranged = 0;
	if (nl) {
		*nl = 0;
		if (sscanf(nl + 1, "%llu\n%llu", &first, &last) != 2 || first < 1 || last < first || last - first > 65535) { buf_str(reply, "ERR:usage base\\nfirst\\nlast"); free(base); return; }
		ranged = 1;
	}
	size_t blen = strlen(base);
	while (blen > 1 && base[blen - 1] == '/') base[--blen] = 0;
	if (base[0] != '/') { buf_str(reply, "ERR:base must be absolute"); free(base); return; }
	textout_t t; memset(&t, 0, sizeof t);
	int ok = 1;
	if (!ranged) ok = text_subtree(&t, blen == 1 ? "" : base, base);
	else {
		char *prefix = xmalloc(blen + 32);
		for (unsigned long long id = first; ok && id <= last; id++) {
			snprintf(prefix, blen + 32, "%s/%llu", blen == 1 ? "" : base, id);
			ok = text_subtree(&t, blen == 1 ? "" : base, prefix);
		}
		free(prefix);
	}
	if (ok) {
		buf_fmt(reply, "%llu;", (unsigned long long)t.missing_count);
		buf_put(reply, t.missing.p, t.missing.n);
		buf_put(reply, t.text.p, t.text.n);
	} else buf_str(reply, "ERR:corrupt value");
	free(t.text.p); free(t.missing.p); free(t.open); free(base);
}

/* Write mode: read back the last value written to path, from the partial
 * file. The game uses it for the few late appends to an entry whose segment
 * was already handed over (roster drain, animal sweep). */
static FILE *write_reader;
static void close_write_reader(void) { if (write_reader) { fclose(write_reader); write_reader = NULL; } }
static int write_get(const char *path, buf_t *reply) {
	size_t i = node_count;
	while (i-- > 0) if (strcmp(nodes[i].path, path) == 0) break;
	if (i == (size_t)-1) { buf_byte(reply, '?'); return 1; }
	if (fflush(out_file) != 0) return 0;
	if (!write_reader && !(write_reader = fopen(tmp_path, "rb"))) return 0;
	rblob_offs = xrealloc(rblob_offs, (blob_count + 1) * sizeof *rblob_offs);
	for (size_t j = 0; j < blob_count; j++) rblob_offs[j] = blobs[j].offset;
	rblob_count = blob_count;
	FILE *saved = in_file;
	in_file = write_reader; in_path = out_path;
	int ok = fseeko(in_file, (int64_t)nodes[i].off, SEEK_SET) == 0 && emit_value_wire(reply);
	in_file = saved;
	return ok;
}

/* ---------- pipe loop ---------- */

static int read_exact(void *d, size_t n) { return fread(d, 1, n, stdin) == n; }
static void reply_buf(const char *d, size_t n) {
	unsigned char h[4] = { (unsigned char)n, (unsigned char)(n >> 8), (unsigned char)(n >> 16), (unsigned char)(n >> 24) };
	fwrite(h, 1, 4, stdout); if (n) fwrite(d, 1, n, stdout); fflush(stdout);
}
static void reply_str(const char *s) { reply_buf(s, strlen(s)); }

static int serve(int write_mode) {
	buf_t payload = {0}, reply = {0};
	for (;;) {
		unsigned char h[5];
		if (!read_exact(h, 5)) break; /* parent went away */
		uint32_t len = h[1] | (uint32_t)h[2] << 8 | (uint32_t)h[3] << 16 | (uint32_t)h[4] << 24;
		payload.n = 0; buf_reserve(&payload, (size_t)len + 1);
		if (len && !read_exact(payload.p, len)) break;
		payload.n = len; payload.p[len] = 0;
		reply.n = 0;
		char err[200] = {0};
		switch (h[0]) {
		case OP_WRITE:
			if (!write_mode || !out_file) { reply_str("ERR:not writing"); break; }
			if (handle_write(payload.p, payload.n, err, sizeof err)) reply_str("OK");
			else { buf_str(&reply, "ERR:"); buf_str(&reply, err); reply_buf(reply.p, reply.n); }
			break;
		case OP_FINISH:
			if (!write_mode || !out_file) { reply_str("ERR:not writing"); break; }
			finish_write(payload.n == 5 && memcmp(payload.p, "force", 5) == 0, &reply);
			reply_buf(reply.p, reply.n);
			break;
		case OP_ABORT:
			close_write_reader();
			if (out_file) { fclose(out_file); out_file = NULL; remove(tmp_path); }
			reply_str("OK");
			break;
		case OP_GET:
			if (write_mode && !out_file) { reply_str("ERR:not writing"); break; }
			if (!(write_mode ? write_get(payload.p, &reply) : get_value(payload.p, &reply))) { reply.n = 0; buf_str(&reply, "ERR:corrupt value"); }
			reply_buf(reply.p, reply.n);
			break;
		case OP_ITER: {
			if (write_mode) { reply_str("ERR:not reading"); break; }
			unsigned long long start = 0, max = 0;
			if (sscanf(payload.p, "%llu;%llu", &start, &max) != 2 || !max) { reply_str("ERR:usage start;max"); break; }
			uint64_t i = start;
			buf_t body = {0};
			for (; i < rcount && i < start + max; i++) {
				size_t plen = strlen(rpaths[i]);
				emit_wire_string(&body, 'W', rpaths[i], plen);
				fseeko(in_file, (int64_t)roffs[i], SEEK_SET);
				if (!emit_value_wire(&body)) break;
			}
			if (i < rcount && i < start + max) { reply_str("ERR:corrupt value"); free(body.p); break; }
			buf_fmt(&reply, "%llu;", (unsigned long long)i);
			buf_put(&reply, body.p, body.n);
			free(body.p);
			reply_buf(reply.p, reply.n);
			break;
		}
		case OP_SEEK:
			if (write_mode) { reply_str("ERR:not reading"); break; }
			buf_fmt(&reply, "%llu", (unsigned long long)seek_path(payload.p));
			reply_buf(reply.p, reply.n);
			break;
		case OP_TEXT:
			if (write_mode) { reply_str("ERR:not reading"); break; }
			text_value(payload.p, &reply);
			reply_buf(reply.p, reply.n);
			break;
		case OP_DIR:
			if (write_mode) { reply_str("ERR:not reading"); break; }
			dir_value(payload.p, &reply);
			reply_buf(reply.p, reply.n);
			break;
		case OP_STATS:
			buf_fmt(&reply, "{\"mode\":\"%s\",\"nodes\":%llu,\"records\":%llu,\"bytes\":%llu,\"blobs\":%llu,\"helper_peak_rss_kb\":%ld}",
				write_mode ? "write" : "read", (unsigned long long)(write_mode ? node_count : rcount), (unsigned long long)record_count,
				(unsigned long long)out_pos, (unsigned long long)(write_mode ? blob_count : rblob_count), peak_rss_kb());
			reply_buf(reply.p, reply.n);
			break;
		case OP_QUIT:
			reply_str("OK");
			goto done;
		default:
			reply_str("ERR:unknown op");
		}
	}
done:
	close_write_reader();
	if (out_file) { fclose(out_file); out_file = NULL; remove(tmp_path); }
	free(payload.p); free(reply.p);
	return 0;
}

int main(int argc, char **argv) {
#ifdef _WIN32
	_setmode(_fileno(stdin), _O_BINARY);
	_setmode(_fileno(stdout), _O_BINARY);
#endif
	if (argc < 3) { fprintf(stderr, "usage: %s write|read|dump <file>\n", argv[0]); return 2; }
	if (strcmp(argv[1], "write") == 0) {
		out_path = argv[2];
		size_t n = strlen(out_path);
		tmp_path = xmalloc(n + 5); memcpy(tmp_path, out_path, n); memcpy(tmp_path + n, ".tmp", 5);
		out_file = fopen(tmp_path, "wb");
		if (!out_file) { fprintf(stderr, "cannot create %s\n", tmp_path); return 1; }
		setvbuf(out_file, NULL, _IOFBF, 1 << 20);
		buf_t h = {0}; buf_put(&h, SAVESTREAM_MAGIC, 8); buf_u32(&h, SAVESTREAM_VERSION); buf_u32(&h, 0);
		out_write(h.p, h.n); free(h.p);
		return serve(1);
	}
	char err[200] = {0};
	in_path = argv[2];
	if (!open_reader(argv[2], err, sizeof err)) { fprintf(stderr, "%s\n", err); if (strcmp(argv[1], "read") == 0) { /* report on the pipe too */ unsigned char h[5]; if (fread(h, 1, 5, stdin) == 5) { char m[220]; snprintf(m, sizeof m, "ERR:%s", err); reply_str(m); } } return 1; }
	if (strcmp(argv[1], "read") == 0) return serve(0);
	if (strcmp(argv[1], "dump") == 0) {
		buf_t line = {0};
		for (uint64_t i = 0; i < rcount; i++) {
			line.n = 0;
			fseeko(in_file, (int64_t)roffs[i], SEEK_SET);
			if (!emit_value_wire(&line)) { fprintf(stderr, "corrupt value at %s\n", rpaths[i]); return 1; }
			fputs(rpaths[i], stdout); fputc('\t', stdout); fwrite(line.p, 1, line.n, stdout); fputc('\n', stdout);
		}
		return 0;
	}
	fprintf(stderr, "unknown mode %s\n", argv[1]);
	return 2;
}
