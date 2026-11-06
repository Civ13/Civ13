/* Civ13 stream save format, version 1 (prototype).
 *
 * A stream file stores the same logical tree a BYOND /savefile level holds:
 * absolute paths ("/entries/0/17/name") mapped to values. It is written
 * sequentially by the 64-bit helper and indexed at the end, so neither the
 * writer nor the 32-bit game process ever holds the whole tree.
 *
 * Layout (all integers little endian, varints are unsigned LEB128):
 *   header   "C13STRM\0" u32 version(1) u32 flags(0)
 *   records  repeated:
 *              'V' value                           a node value (its path is in the index)
 *              'B' varint id varint params_len params varint size bytes
 *                                                  a deduplicated file blob
 *   index    varint node_count, then sorted by path, front coded:
 *              varint shared_prefix varint rest_len rest varint value_offset
 *            varint blob_count, then u64 record_offset per blob id
 *   A file without the trailer is incomplete and is never read.
 *   trailer  u64 index_offset u64 node_count "C13SIDX\0"
 *
 * Values:
 *   'n' null
 *   'f' f32                       number (BYOND numbers are float32)
 *   's' varint len bytes          text (UTF-8)
 *   'p' varint len bytes          type path
 *   'l' varint count, count x (value key, u8 has_assoc, [value assoc])
 *   'd' varint blob_id            file data (icons, sounds), deduplicated
 *   'x' varint len bytes          raw BYOND savefile text for values with no
 *                                 native form (appearances, saved objects)
 *   'y' varint blob_id            a one-node BYOND savefile holding the value at
 *                                 "v", for values whose text does not import
 *                                 back (mutable appearances)
 *
 * Wire tokens (text, between DM and the helper). Lengths are byte counts.
 *   N                 null
 *   F<number>;        number, printed with 9 significant digits or inf/-inf/nan
 *   S<len>:<bytes>    text
 *   P<len>:<bytes>    type path
 *   L<count>;         list, followed by count items: <key token> then
 *                     '=' <value token> for an associated value or '.'
 *   X<len>:<bytes>    BYOND savefile text of one value (". = " stripped),
 *                     optionally followed by its indented child lines
 *   Y<len>:<path>     a one-node savefile file ("v") holding the value; the
 *                     reader of the token deletes the file
 * A write batch is a sequence of  W<len>:<path> <value token>  records.
 */
#ifndef SAVESTREAM_FORMAT_H
#define SAVESTREAM_FORMAT_H

#define SAVESTREAM_MAGIC "C13STRM"
#define SAVESTREAM_INDEX_MAGIC "C13SIDX"
#define SAVESTREAM_VERSION 1u

/* Helper pipe protocol: request = u8 op, u32 len, payload.
 * Reply = u32 len, payload. Every request gets exactly one reply. */
#define OP_WRITE 'W'  /* payload: write batch; reply "OK" or "ERR:..." */
#define OP_FINISH 'F' /* reply: JSON summary; file is published on success */
#define OP_ABORT 'A'  /* discard the partial file */
#define OP_GET 'G'    /* payload: path; reply: wire token or "?" if absent. In write
                       * mode it reads the last value written to that path. */
#define OP_DIR 'D'    /* payload: path; reply: L token of child names */
#define OP_ITER 'I'   /* payload: "<start>;<max>"; reply: "<next>;" then W records in index order */
#define OP_SEEK 'K'   /* read: payload path; reply: decimal index of the first node at or after it */
#define OP_STATS 'S'  /* reply: JSON */
#define OP_QUIT 'Q'

#endif
