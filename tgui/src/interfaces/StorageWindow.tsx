import { useEffect, useMemo, useRef, useState, type DragEvent, type KeyboardEvent, type ReactNode } from 'react';
import { Button } from 'tgui-core/components';
import type { StorageGroup, StorageItem, StorageWindowData } from '../data';
import type { ScreenProps } from '../types';
import { list, str } from './common';
import { Pill } from './kit';

// The storage window (design by Fable): what you carry on the left, what is
// around you on the right, the moves waiting along the bottom. Every move is
// timed on the server; this screen only asks for moves and shows them running.

const SIZE_NAMES = ['', 'tiny', 'small', 'normal', 'large', 'bulky'];

function Sprite({ image, small = false }: { image: unknown; small?: boolean }) {
  const src = typeof image === 'string' && /^stor_[0-9a-f]{32}\.png$/.test(image) ? image : '';
  const size = small ? 24 : 32;
  return src ? <img className="stor-sprite" src={src} width={size} height={size} alt="" /> : <span className="stor-sprite" aria-hidden="true" />;
}

function seconds(ds: number) { return `${(Math.max(0, ds) / 10).toFixed(1)} s`; }

// Highlight the part of a name that matches the find box.
function Marked({ name, query }: { name: string; query: string }) {
  const at = query ? name.toLowerCase().indexOf(query) : -1;
  if (at < 0) return <>{name}</>;
  return <>{name.slice(0, at)}<mark>{name.slice(at, at + query.length)}</mark>{name.slice(at + query.length)}</>;
}

// A grey "?" box drawn at the unseen thing's size class.
function Unknown({ size }: { size: unknown }) {
  const n = Math.min(5, Math.max(1, Number(size) || 3));
  return <span className={`stor-q stor-q-${n}`} aria-hidden="true"><i>?</i></span>;
}

// Why a container would refuse what is being dragged, as one short sentence.
export function refusal(group: StorageGroup, moving: StorageItem[], handsFree: number): ReactNode {
  if (group.locked) return 'It is locked.';
  if (group.kind === 'hands') return moving.length > handsFree ? <><b>No free hand.</b> Put something down first.</> : null;
  if (group.kind === 'floor') return null;
  const items = list(group.items);
  const max = Number(group.max_size) || 0;
  const big = max ? moving.find(item => (Number(item.size_class) || 0) > max) : undefined;
  if (big) return <><b>Too big:</b> {str(big.name)} won&apos;t fit.</>;
  if (group.kind === 'pockets') return items.length + moving.length > 2 ? <><b>No free pocket.</b></> : null;
  const slots = Number(group.slots) || 0;
  if (slots && items.length + moving.length > slots) return <><b>No free slot.</b> Take something out first.</>;
  if (group.unit === 'things') return null;
  const space = Number(group.space) || 0;
  const cost = moving.reduce((sum, item) => sum + (Number(item.cost) || 0), 0);
  if (space && (Number(group.used) || 0) + cost > space) return <><b>Not enough room.</b> Needs {cost}, has {space - (Number(group.used) || 0)}.</>;
  return null;
}

function Tile({ item, query, selected, onPick, onDrag, onEnter, interactive }: {
  item: StorageItem; query: string; selected: boolean; interactive: boolean;
  onPick: () => void; onDrag: (event: DragEvent) => void; onEnter: () => void;
}) {
  const busy = !!item.moving || !!item.queued;
  const name = str(item.name);
  const size = str(item.size) || SIZE_NAMES[Number(item.size_class) || 0] || '';
  let cls = 'stor-item';
  if (item.moving) cls += ' stor-item-moving';
  else if (item.queued) cls += ' stor-item-queued';
  else if (selected) cls += ' stor-item-selected';
  const onKey = (event: KeyboardEvent) => { if (event.key === 'Enter') { event.preventDefault(); onEnter(); } };
  return <button type="button" className={cls} title={name} aria-pressed={selected} disabled={!interactive || busy}
    draggable={interactive && !busy} onDragStart={onDrag} onClick={onPick} onKeyDown={onKey}>
    <Sprite image={item.image} />
    <span className="stor-item-text"><strong><Marked name={name} query={query} /></strong>
      <small>{item.moving ? 'moving' : item.queued ? 'waiting' : size}</small></span>
    {Number(item.count) > 1 && <span className="stor-count">{Number(item.count)}</span>}
  </button>;
}

type Drag = { ids: string[]; from: string };

export function StorageWindow(ui: ScreenProps<StorageWindowData>) {
  const { data, act, interactive } = ui;
  const [query, setQuery] = useState('');
  const [picked, setPicked] = useState<string[]>([]);
  const [shut, setShut] = useState<Record<string, boolean>>({});
  const [asking, setAsking] = useState('');
  const [drag, setDrag] = useState<Drag | null>(null);
  const [over, setOver] = useState('');
  const lastTarget = useRef('');
  const find = query.trim().toLowerCase();

  const hands = list(data.hands);
  const you = list(data.you);
  const near = list(data.near);
  const groups = [...you, ...near];
  const items = useMemo(() => {
    const all: Record<string, StorageItem> = {};
    for (const hand of hands) if (hand.item?.id) all[str(hand.item.id)] = hand.item;
    for (const group of groups) for (const item of list(group.items)) if (item.id) all[str(item.id)] = item;
    return all;
  }, [data]);
  const groupOf = (id: string) => groups.find(group => str(group.id) === id);
  const handsFree = hands.filter(hand => !hand.item).length;
  // Older snapshots may not have sent the server's limit yet.
  const snapshotMoveLimit = Number(data.move_limit);
  const moveLimit = Number.isInteger(snapshotMoveLimit) && snapshotMoveLimit > 0 ? snapshotMoveLimit : 40;
  const tooMany = (ids: string[]) => ids.length > moveLimit;
  const limitMessage = `Move up to ${moveLimit} ${moveLimit === 1 ? 'item' : 'items'} at a time. Deselect items to continue.`;

  // A selection keeps only things still listed and not already on the move.
  useEffect(() => { setPicked(old => old.filter(id => items[id] && !items[id].queued && !items[id].moving)); }, [items]);
  // More pictures are waiting on the server: ask for the next batch.
  useEffect(() => { if (data.more_images && interactive) act('images'); }, [data]);
  // Opening a bag again brings it into view and opens it.
  const focusSeq = Math.max(0, ...groups.map(group => Number(group.focus) || 0));
  useEffect(() => {
    const target = groups.find(group => (Number(group.focus) || 0) === focusSeq && focusSeq > 0);
    if (!target) return;
    setShut(old => ({ ...old, [str(target.id)]: false }));
    document.getElementById(`stor-${str(target.id)}`)?.scrollIntoView?.({ block: 'nearest' });
  }, [focusSeq]);

  // The running move's and the search's bars advance here between snapshots.
  const queue = list(data.queue);
  const searching = groups.some(group => group.search);
  const [tick, setTick] = useState(0);
  const stamp = useRef(Date.now());
  useEffect(() => { stamp.current = Date.now(); setTick(0); }, [data]);
  useEffect(() => {
    if (!queue.length && !searching) return;
    const timer = setInterval(() => setTick((Date.now() - stamp.current) / 100), 100);
    return () => clearInterval(timer);
  }, [queue.length, searching]);

  const moveTo = (to: string, ids: string[]) => {
    if (!interactive || !ids.length || !to || tooMany(ids)) return;
    lastTarget.current = to;
    act('move', { value: ids.join(','), to });
    setPicked([]);
  };
  const pick = (id: string) => setPicked(old => old.includes(id) ? old.filter(other => other !== id) : [...old, id]);
  const startDrag = (id: string, from: string) => (event: DragEvent) => {
    const ids = picked.includes(id) ? picked : [id];
    event.dataTransfer?.setData('text/plain', ids.join(','));
    if (event.dataTransfer) event.dataTransfer.effectAllowed = 'move';
    setDrag({ ids, from });
  };
  const moving = drag ? drag.ids.map(id => items[id]).filter(Boolean) : picked.map(id => items[id]).filter(Boolean);
  const dragRefusal = (group: StorageGroup) => !drag || drag.from === str(group.id) ? null
    : tooMany(drag.ids) ? limitMessage : refusal(group, moving, handsFree);
  const dropProps = (group: StorageGroup) => {
    const id = str(group.id);
    const why = dragRefusal(group);
    return {
      onDragOver: (event: DragEvent) => { if (!drag || drag.from === id) return; if (!why) event.preventDefault(); setOver(id); },
      onDragLeave: () => setOver(old => old === id ? '' : old),
      onDrop: (event: DragEvent) => { event.preventDefault(); if (drag && drag.from !== id && !why) moveTo(id, drag.ids); setDrag(null); setOver(''); },
    };
  };
  const endDrag = () => { setDrag(null); setOver(''); };

  const matches = (item: StorageItem) => !find || str(item.name).toLowerCase().includes(find);
  let shownCount = 0, totalCount = 0;
  for (const hand of hands) if (hand.item) { totalCount++; if (matches(hand.item)) shownCount++; }
  for (const group of groups) for (const item of list(group.items)) { totalCount++; if (matches(item)) shownCount++; }

  const renderGroup = (group: StorageGroup) => {
    const id = str(group.id);
    const all = list(group.items);
    const shown = all.filter(matches);
    const unseen = list(group.unseen);
    const search = group.search && typeof group.search === 'object' ? group.search : null;
    const hidden = unseen.length + (search ? 1 : 0);
    const nomatch = !!find && !shown.length;
    // A container nobody has looked into yet stays shut until you search it.
    const unsearched = hidden > 0 && !search && !all.length;
    const open = !shut[id] && !group.locked && !nomatch && !unsearched;
    const why = over === id ? dragRefusal(group) : null;
    let cls = 'stor-group';
    if (!open) cls += ' stor-shut';
    if (nomatch) cls += ' stor-group-nomatch';
    if (drag && over === id && drag.from !== id) cls += why ? ' stor-group-refused' : ' stor-group-drop';
    // Crates count things rather than space.
    const counted = group.unit === 'things';
    const used = Number(group.used) || 0, space = (counted ? Number(group.slots) : Number(group.space)) || 0;
    const full = space > 0 && used / space >= 0.85;
    const room = group.kind === 'pockets' ? `${all.length} / 2 pockets` : space ? `${used} / ${space} ${counted ? 'things' : 'space'}` : '';
    const canMoveHere = interactive && picked.length > 0 && !group.locked && !picked.some(pid => all.some(item => str(item.id) === pid));
    return <section key={id} id={`stor-${id}`} className={cls} aria-label={str(group.name)} {...dropProps(group)}>
      <div className="stor-head">
        {!group.locked && <button type="button" className="stor-toggle" aria-expanded={open} aria-label={open ? 'Close' : 'Open'}
          onClick={() => setShut(old => ({ ...old, [id]: open }))} />}
        <Sprite image={group.image} />
        <span className="stor-name">{str(group.name)}</span>
        {search && <Pill tone="progress">Searching... {all.length + 1} of {Number(group.total) || all.length + hidden}</Pill>}
        {group.locked ? <Pill tone="warn">Locked</Pill> : !open && room && !search ? <span className={`stor-space${full ? ' stor-space-full' : ''}`}>{room}</span> : null}
        {find && !nomatch && shown.length < all.length && <span className="stor-space">{shown.length} of {all.length} shown</span>}
        {!nomatch && <span className="stor-actions">
          {interactive && hidden > 0 && !search && !find && <Button onClick={() => { setShut(old => ({ ...old, [id]: false })); act('search', { value: id }); }}>Search</Button>}
          {canMoveHere && <Button className="stor-primary" onClick={() => moveTo(id, picked)}>Move here</Button>}
          {!!group.can_take && all.length > 0 && <Button disabled={!interactive} onClick={() => act('take_all', { value: id })}>Take all</Button>}
          {!!group.can_dump && all.length > 0 && group.kind !== 'floor' && <Button disabled={!interactive} onClick={() => setAsking(id)}>Dump out</Button>}
        </span>}
      </div>
      {group.locked && <p className="stor-note">You can&apos;t open it.</p>}
      {why && <p className="stor-why stor-why-no">{why}</p>}
      {asking === id && <div className="stor-confirm" role="group" aria-label="Dump out">
        <span>Tip {all.length === 1 ? 'the one thing' : `all ${all.length} things`} onto the floor? <small>Each one takes a moment.</small></span>
        <Button className="stor-primary" onClick={() => { act('dump', { value: id }); setAsking(''); }}>Dump out</Button>
        <Button onClick={() => setAsking('')}>Keep</Button>
      </div>}
      {open && space > 0 && <div className="stor-room"><div className={`stor-fill${full ? ' stor-fill-full' : ''}`}><div style={{ width: `${Math.min(100, Math.round(used * 100 / space))}%` }} /></div>
        <span className={`stor-space${full ? ' stor-space-full' : ''}`}>{room}</span></div>}
      {open && <div className="stor-slots">
        {shown.length ? shown.map(item => <Tile key={str(item.id)} item={item} query={find} interactive={interactive}
          selected={picked.includes(str(item.id))} onPick={() => pick(str(item.id))} onDrag={startDrag(str(item.id), id)}
          onEnter={() => moveTo(lastTarget.current, picked.length ? picked : [str(item.id)])} />)
          : hidden && !find ? null : <p className="stor-empty">{group.kind === 'floor' ? 'Nothing on the floor.' : 'Empty.'}</p>}
        {search && !find && <span className="stor-item stor-item-unknown stor-item-searching">
          <Unknown size={search.size_class} /><span className="stor-item-text"><strong>?</strong><small>looking - {seconds((Number(search.time) || 0) - Math.min(Number(search.time) || 0, (Number(search.done) || 0) + tick))}</small></span></span>}
        {unseen.length > 0 && !find && <div className="stor-unseen">{unseen.map((size, i) => <Unknown key={i} size={size} />)}
          <small>{unseen.length} not seen yet</small></div>}
      </div>}
      {unsearched && !group.locked && !find && <p className="stor-note">{hidden === 1 ? 'Something is' : `${hidden} things are`} inside. Search it to see what.</p>}
    </section>;
  };

  const handsId = str(data.hands_id);
  const handsGroup: StorageGroup = { id: handsId, kind: 'hands', name: 'Hands', items: [] };
  let lastOwner = '';
  const nearRows: ReactNode[] = [];
  for (const group of near) {
    const owner = str(group.owner);
    if (owner && owner !== lastOwner) nearRows.push(<h3 key={`owner-${owner}`} className="stor-sub">{owner}</h3>);
    lastOwner = owner;
    nearRows.push(renderGroup(group));
  }

  const total = queue.reduce((sum, job) => sum + (Number(job.time) || 0), 0);
  const firstDone = queue.length ? Math.min(Number(queue[0].time) || 0, (Number(queue[0].done) || 0) + tick) : 0;
  return <div className="stor" onDragEnd={endDrag}>
    <div className="stor-bar">
      <input type="search" aria-label="Find" placeholder="Find..." value={query} maxLength={40} onChange={event => setQuery(event.target.value)} />
      {find ? <span className="stor-bar-note"><b>{shownCount}</b> of {totalCount} things shown - <button type="button" className="stor-link" onClick={() => setQuery('')}>Clear</button></span>
        : picked.length ? <span className="stor-bar-note"><b>{picked.length}</b> selected - <button type="button" className="stor-link" onClick={() => setPicked([])}>Clear</button></span>
          : <span className="stor-bar-note">Drag things, or select them and press Move here.</span>}
      {tooMany(picked) && <span className="stor-bar-note" role="status">{limitMessage}</span>}
    </div>
    <div className="stor-columns">
      <div className="stor-pane" aria-label="You">
        <h2>You</h2>
        <div className={`stor-hands${drag && over === handsId ? ' stor-group-drop' : ''}`} {...dropProps(handsGroup)}>
          {hands.map(hand => {
            const side = str(hand.side) === 'left' ? 'Left hand' : 'Right hand';
            return hand.item
              ? <Tile key={str(hand.side)} item={hand.item} query={find} interactive={interactive} selected={picked.includes(str(hand.item.id))}
                onPick={() => pick(str(hand.item!.id))} onDrag={startDrag(str(hand.item.id), handsId)}
                onEnter={() => moveTo(lastTarget.current, picked.length ? picked : [str(hand.item!.id)])} />
              : <span key={str(hand.side)} className={`stor-item stor-item-none${hand.active ? ' stor-item-active' : ''}`}>
                <span className="stor-sprite" aria-hidden="true" /><span className="stor-item-text"><strong>{side}</strong><small>empty</small></span></span>;
          })}
          {interactive && picked.length > 0 && handsFree > 0 && <Button className="stor-primary" onClick={() => moveTo(handsId, picked)}>To hands</Button>}
        </div>
        {you.map(renderGroup)}
      </div>
      <div className="stor-pane" aria-label="Nearby">
        <h2>Nearby</h2>
        {nearRows}
      </div>
    </div>
    {queue.length ? <div className="stor-queue" aria-label="Moves">
      <div className="stor-queue-sum"><strong>Moving <b>{queue.length}</b> - {seconds(total - firstDone)} left</strong><small>Walking away cancels.</small></div>
      <div className="stor-jobs">{queue.slice(0, 4).map((job, i) => {
        const time = Number(job.time) || 1;
        const done = i === 0 ? firstDone : 0;
        return <div key={i} className={`stor-job${i === 0 ? ' stor-job-now' : ''}`}>
          <Sprite image={job.image} small />
          <span className="stor-job-name"><b>{str(job.name)}</b>{queue.length === 1 && <small>to {str(job.to)}</small>}</span>
          <div className="stor-job-track"><div style={{ width: `${Math.min(100, Math.round(done * 100 / time))}%` }} /></div>
          <span className="stor-job-time">{seconds(time - done)}</span>
        </div>;
      })}</div>
      {queue.length > 4 && <span className="stor-more">+{queue.length - 4} more</span>}
      <Button disabled={!interactive} onClick={() => act('cancel')}>Cancel all</Button>
    </div> : <div className="stor-queue stor-queue-idle">Moving things takes a moment: bigger things take longer, your hands and belt are quicker.</div>}
  </div>;
}
