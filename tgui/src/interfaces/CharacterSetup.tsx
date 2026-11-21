import { useState } from 'react';
import type { ReactNode } from 'react';
import { Button, NoticeBox, Section } from 'tgui-core/components';
import type { CharacterSetupData, SetupTrait } from '../data';
import type { ScreenProps } from '../types';
import { Action, list, str } from './common';
import { Choice, Pill, Row, Rows } from './kit';

// Character setup: who you are, the traits you take and your own settings.
// Every control sends one action at once; the server answers with the new state.
type UI = ScreenProps<CharacterSetupData>;
const tabs = [['character', 'Character'], ['traits', 'Traits'], ['chart', 'Birth chart'], ['settings', 'Settings']] as const;
type Tab = typeof tabs[number][0];

export function CharacterSetup(ui: UI) {
  const { data } = ui;
  const [tab, setTab] = useState<Tab>(tabs.some(([key]) => key === data.tab) ? data.tab as Tab : 'character');
  const traits = data.traits ?? {};
  const over = Number(traits.spent ?? 0) - Number(traits.earned ?? 0);
  // A living character keeps its body and traits; settings stay open.
  const locked = !!data.locked;
  const own: UI = locked ? { ...ui, interactive: false } : ui;
  return <div className="setup">
    <div className="setup-tabs" role="tablist">{tabs.map(([key, label]) =>
      <button key={key} type="button" role="tab" aria-selected={tab === key} className={tab === key ? 'setup-tab setup-tab-on' : 'setup-tab'} onClick={() => setTab(key)}>
        {label}{key === 'traits' && over > 0 ? <Pill tone="warn">{over} over</Pill> : null}
        {key === 'traits' && over <= 0 && list(traits.chosen).length ? <Pill tone="muted">{list(traits.chosen).length}</Pill> : null}
      </button>)}</div>
    {!!data.notice && <NoticeBox danger>{str(data.notice)}</NoticeBox>}
    {locked && tab !== 'settings' && tab !== 'chart' && <NoticeBox>You can change your character and traits once this one has died.</NoticeBox>}
    {tab === 'character' && <Character ui={own} />}
    {tab === 'traits' && <Traits ui={own} />}
    {tab === 'chart' && <Chart ui={own} />}
    {tab === 'settings' && <Settings ui={ui} />}
  </div>;
}

// A text or number box that sends its value on Enter or when left.
function Field({ ui, action, value, number, min, max, maxLength, width, label }: { ui: UI; action: string; value: string | number; number?: boolean; min?: number; max?: number; maxLength?: number; width?: number; label: string }) {
  const [typed, setTyped] = useState<string | null>(null);
  const shown = typed ?? String(value);
  const commit = () => {
    if (typed === null) return;
    setTyped(null);
    if (typed === String(value)) return;
    if (number) { if (typed.trim() !== '' && Number.isFinite(Number(typed))) ui.act(action, { value: Number(typed) }); }
    else if (typed.trim() !== '') ui.act(action, { value: typed });
  };
  return <input className="setup-field" type={number ? 'number' : 'text'} aria-label={label} min={min} max={max} maxLength={maxLength} style={width ? { width } : undefined}
    value={shown} disabled={!ui.interactive} onChange={event => setTyped(event.target.value)} onBlur={commit}
    onKeyDown={event => { if (event.key === 'Enter') commit(); }} />;
}

function Swatches({ ui, action, colors, current, label }: { ui: UI; action: string; colors: unknown; current?: string; label: string }) {
  return <span className="setup-swatches" role="group" aria-label={label}>{list(colors).map(color => {
    const name = str(color.name), hex = /^#[0-9a-f]{6}$/i.test(str(color.hex)) ? str(color.hex) : '#000000';
    return <button key={name} type="button" title={name} aria-label={name} aria-pressed={name === current} disabled={!ui.interactive}
      className={name === current ? 'setup-swatch setup-swatch-on' : 'setup-swatch'} style={{ background: hex }} onClick={() => ui.act(action, { value: name })} />;
  })}<span className="setup-swatch-name">{str(current)}</span></span>;
}

// A long list of named styles: a box to narrow it and the names as buttons.
function StylePicker({ ui, action, options, current, label }: { ui: UI; action: string; options: unknown; current?: string; label: string }) {
  const [find, setFind] = useState('');
  const names = list(options).map(option => str(option));
  const shown = find ? names.filter(name => name.toLowerCase().includes(find.toLowerCase())) : names;
  return <div className="setup-styles">
    {names.length > 16 && <input className="setup-field setup-find" type="text" placeholder={`Find among ${names.length}`} aria-label={`Find ${label}`} value={find} onChange={event => setFind(event.target.value)} />}
    <div className="setup-style-list" role="group" aria-label={label}>
      {shown.map(name => <Action key={name} ui={ui} action={action} value={name} selected={name === current}>{name}</Action>)}
      {!shown.length && <span className="kit-hint">Nothing by that name.</span>}
    </div>
  </div>;
}

const sides = ['front', 'east', 'back', 'west'] as const;
function Preview({ ui }: { ui: UI }) {
  const views = list(ui.data.character?.previews);
  const [side, setSide] = useState(0);
  const [view, setView] = useState(1);
  const shown = views[Math.min(view, views.length - 1)];
  const file = shown ? str(shown[sides[side]]) : '';
  return <div className="setup-preview">
    <div className="setup-stage">{/^[\w-]+\.png$/.test(file) ? <img src={file} width={192} height={192} alt={`Your character from the ${sides[side]}`} /> : null}</div>
    <div className="setup-turn">
      <button type="button" className="setup-turn-button" aria-label="Turn left" onClick={() => setSide((side + 3) % 4)}>&#9664;</button>
      <span>{sides[side]}</span>
      <button type="button" className="setup-turn-button" aria-label="Turn right" onClick={() => setSide((side + 1) % 4)}>&#9654;</button>
    </div>
    {views.length > 1 && <span className="kit-choice" role="group" aria-label="Preview clothing">{views.map((option, i) =>
      <Button key={i} selected={i === Math.min(view, views.length - 1)} onClick={() => setView(i)}>{str(option.label)}</Button>)}</span>}
  </div>;
}

function Character({ ui }: { ui: UI }) {
  const c = ui.data.character ?? {};
  const [tone, setTone] = useState<number | null>(null);
  const sendTone = () => { if (tone !== null) { if (tone !== c.skin_tone) ui.act('skin_tone', { value: tone }); setTone(null); } };
  const yesNo = (action: string, on: unknown, label: string) => <Choice ui={ui} action={action} value={on ? 1 : 0} label={label} options={[[1, 'Yes'], [0, 'No']]} />;
  return <div className="setup-columns">
    <div className="setup-side">
      <Preview ui={ui} />
      <p className="setup-summary">{str(c.summary)}</p>
      <Action ui={ui} action="randomize">Randomise appearance</Action>
    </div>
    <div className="setup-main">
      <Section title="Identity"><Rows>
        <Row label="Name" buttons={<Action ui={ui} action="random_name">Random name</Action>}>
          <Field ui={ui} action="name" value={str(c.name)} maxLength={Number(c.name_max ?? 45)} label="Name" /></Row>
        <Row label="New name every round">{yesNo('always_random_name', c.random_name, 'New name every round')}</Row>
        <Row label="New body every round">{yesNo('always_random_body', c.random_body, 'New body every round')}</Row>
        <Row label="Gender"><Choice ui={ui} action="gender" value={c.gender} label="Gender" options={[['male', 'Male'], ['female', 'Female']]} /></Row>
        <Row label="Age"><Field ui={ui} action="age" value={Number(c.age ?? 0)} number min={c.age_min} max={c.age_max} width={72} label="Age" />
          <span className="kit-hint setup-inline">{c.age_min} to {c.age_max}</span></Row>
        <Row label="Blood type"><Choice ui={ui} action="blood" value={c.blood} label="Blood type" options={list(c.blood_types).map(type => [str(type), str(type)])} /></Row>
      </Rows></Section>
      <Section title="Skin and eyes"><Rows>
        {c.skin_tone != null && <Row label="Skin tone"><span className="setup-tone"><span>Light</span>
          <input type="range" min={1} max={220} aria-label="Skin tone" value={tone ?? Number(c.skin_tone)} disabled={!ui.interactive}
            onChange={event => setTone(Number(event.target.value))} onMouseUp={sendTone} onTouchEnd={sendTone} onKeyUp={sendTone} onBlur={sendTone} />
          <span>Dark</span></span></Row>}
        {!!list(c.eye_colors).length && <Row label="Eyes"><Swatches ui={ui} action="eye_color" colors={c.eye_colors} current={c.eye_color} label="Eye colour" /></Row>}
      </Rows></Section>
      <Section title="Hair">
        {!!list(c.hair_colors).length && <Rows><Row label="Colour"><Swatches ui={ui} action="hair_color" colors={c.hair_colors} current={c.hair_color} label="Hair colour" /></Row></Rows>}
        <StylePicker ui={ui} action="hair_style" options={c.hair_styles} current={c.hair_style} label="Hair style" />
      </Section>
      <Section title="Facial hair">
        {!!list(c.hair_colors).length && <Rows><Row label="Colour"><Swatches ui={ui} action="facial_color" colors={c.hair_colors} current={c.facial_color} label="Facial hair colour" /></Row></Rows>}
        {list(c.facial_styles).length > 1
          ? <StylePicker ui={ui} action="facial_style" options={c.facial_styles} current={c.facial_style} label="Facial hair style" />
          : <p className="kit-hint">{str(c.facial_style)}</p>}
      </Section>
    </div>
  </div>;
}

// What a trait does to the point balance, in the player's terms.
function Cost({ cost }: { cost: number }) {
  if (cost > 0) return <Pill tone="progress">Costs {cost}</Pill>;
  if (cost < 0) return <Pill tone="good">Gives {-cost}</Pill>;
  return <Pill tone="muted">Free</Pill>;
}
const kinds = [['all', 'All'], ['perk', 'Perks'], ['drawback', 'Drawbacks'], ['free', 'Free']] as const;
function TraitCard({ ui, trait, group, strip }: { ui: UI; trait: SetupTrait; group: string[] | null; strip: boolean }) {
  const name = str(trait.name), conflicts = list(trait.conflicts).map(other => str(other)), taken = !!trait.taken, block = trait.block ? str(trait.block) : '';
  // A pick-one group's heading already says what its traits are.
  const desc = strip ? str(trait.desc).replace(/^(Playstyle|Field of study)\.\s*/, '') : str(trait.desc);
  // In a pick-one group the swap is plain from the button; only name what else would go.
  const outside = group ? conflicts.filter(other => !group.includes(other)) : conflicts;
  let button: ReactNode;
  if (taken) button = <Action ui={ui} action="trait_remove" value={name} disabled={!!block}>Remove</Action>;
  else if (conflicts.length) button = <Action ui={ui} action="trait_swap" value={name} disabled={!!block}>{group?.some(other => conflicts.includes(other)) ? 'Choose instead' : 'Swap in'}</Action>;
  else button = <Action ui={ui} action="trait_add" value={name} disabled={!!block}>Take</Action>;
  return <div className={taken ? 'setup-trait setup-trait-on' : 'setup-trait'}>
    <div className="setup-trait-head"><strong>{name}</strong><Cost cost={Number(trait.cost ?? 0)} />{taken && <Pill tone="ready">Taken</Pill>}</div>
    <p className="setup-trait-desc">{desc}</p>
    {!!trait.note && <p className="kit-hint">{str(trait.note)}</p>}
    {!taken && !!outside.length && <p className="kit-hint setup-replaces">Replaces {outside.join(', ')}</p>}
    {!!block && <p className="kit-hint setup-replaces">{block}</p>}
    <div className="setup-trait-foot">{button}</div>
  </div>;
}
function Traits({ ui }: { ui: UI }) {
  const traits = ui.data.traits ?? {};
  const [find, setFind] = useState('');
  const [kind, setKind] = useState<typeof kinds[number][0]>('all');
  const [only, setOnly] = useState('');
  const spent = Number(traits.spent ?? 0), earned = Number(traits.earned ?? 0), over = spent - earned;
  const chosen = list(traits.chosen).map(name => str(name)), invalid = list(traits.invalid);
  const categories = list(traits.categories);
  const wanted = find.trim().toLowerCase();
  const matches = (trait: SetupTrait) => {
    const cost = Number(trait.cost ?? 0);
    if (kind === 'perk' && !(cost > 0)) return false;
    if (kind === 'drawback' && !(cost < 0)) return false;
    if (kind === 'free' && cost !== 0) return false;
    return !wanted || str(trait.name).toLowerCase().includes(wanted) || str(trait.desc).toLowerCase().includes(wanted);
  };
  const shown = categories.filter(category => !only || str(category.id) === only)
    .map(category => ({ category, rows: list(category.traits).filter(matches) })).filter(group => group.rows.length);
  return <>
    <Section title="Your traits" buttons={<><Action ui={ui} action="trait_random">Random set</Action><Action ui={ui} action="trait_clear" disabled={!chosen.length && !invalid.length}>Clear all</Action></>}>
      <div className="setup-balance" role="status">
        <div className="setup-figure"><span>Perks</span><b>{spent}</b></div>
        <div className="setup-figure"><span>Drawbacks</span><b>{earned}</b></div>
        <div className={over > 0 ? 'setup-figure setup-figure-warn' : 'setup-figure setup-figure-good'}><span>{over > 0 ? 'Points over' : 'Points to spare'}</span><b>{Math.abs(over)}</b></div>
        <p className="setup-balance-text">{over > 0
          ? `Drawbacks pay for perks. Take ${over} more ${over === 1 ? 'point' : 'points'} of drawbacks or drop a perk before you join.`
          : 'Drawbacks pay for perks. Your traits are balanced.'}</p>
      </div>
      <div className="setup-chosen">{chosen.length ? chosen.map(name => <span key={name} className="setup-chip">{name}
        <button type="button" aria-label={`Remove ${name}`} disabled={!ui.interactive} onClick={() => ui.act('trait_remove', { value: name })}>&times;</button></span>)
        : <span className="kit-hint">No traits taken. A character needs none.</span>}</div>
      {!!invalid.length && <NoticeBox danger>Saved traits that no longer exist: {invalid.map(entry => str(entry)).join(', ')}. Clear all removes them.</NoticeBox>}
    </Section>
    <div className="setup-columns">
      <div className="setup-side setup-rail">
        <input className="setup-field setup-find" type="text" placeholder="Find a trait" aria-label="Find a trait" value={find} onChange={event => setFind(event.target.value)} />
        <span className="kit-choice setup-kinds" role="group" aria-label="Kind of trait">{kinds.map(([key, label]) =>
          <Button key={key} selected={kind === key} onClick={() => setKind(key)}>{label}</Button>)}</span>
        <nav className="setup-nav" aria-label="Trait categories">
          <button type="button" className={only === '' ? 'setup-nav-item setup-nav-on' : 'setup-nav-item'} onClick={() => setOnly('')}>All categories</button>
          {categories.map(category => {
            const count = list(category.traits).filter(trait => trait.taken).length;
            return <button key={str(category.id)} type="button" className={only === str(category.id) ? 'setup-nav-item setup-nav-on' : 'setup-nav-item'} onClick={() => setOnly(str(category.id))}>
              <span>{str(category.title)}</span>{count ? <Pill tone="ready">{count}</Pill> : <span className="setup-nav-count">{list(category.traits).length}</span>}</button>;
          })}
        </nav>
      </div>
      <div className="setup-main">
        {shown.map(({ category, rows }) => <Section key={str(category.id)} title={str(category.title)} buttons={category.pick_one ? <Pill tone="info">Pick one</Pill> : undefined}>
          {!!category.note && <p className="kit-hint">{str(category.note)}</p>}
          <div className="setup-traits">{rows.map(trait => <TraitCard key={str(trait.name)} ui={ui} trait={trait} group={category.pick_one ? list(category.traits).map(other => str(other.name)) : null} strip={!!category.pick_one} />)}</div>
        </Section>)}
        {!shown.length && <NoticeBox>No trait matches.</NoticeBox>}
      </div>
    </div>
  </>;
}

// The birth chart: drawn at birth unless a verified player picks a sign.
function Chart({ ui }: { ui: UI }) {
  const chart = ui.data.chart ?? {};
  const signs = list(chart.signs);
  const choice = str(chart.choice) || 'random', verified = !!chart.verified, current = chart.current ? str(chart.current) : '';
  const living = !!ui.data.locked;
  return <>
    <Section title="Birth chart">
      <p className="kit-hint">Every character is born under one of twelve signs. A sign leans your starting skills a little: three a bit stronger, three a bit weaker. Its first strength also trains a little faster and its first weakness a little slower, unless one of your traits already changes how fast that skill trains.</p>
      {living
        ? <NoticeBox>{current ? `This character was born under ${signs.find(sign => str(sign.id) === current)?.name ?? current}. A new character can be born under another sign.` : 'This character has no sign.'}</NoticeBox>
        : <div className="setup-chart-random">
          <Action ui={ui} action="birth_chart" value="random" selected={choice === 'random'}>Leave it to the stars</Action>
          <span className="kit-hint">Your sign is drawn when you are born.</span>
        </div>}
      {!living && !verified && <div className="setup-chart-verify">
        <span className="kit-hint">Verify your Discord account to choose your sign.</span>
        <Action ui={ui} action="verify_discord">Verify Discord</Action>
      </div>}
    </Section>
    <div className="setup-traits" role="group" aria-label="Signs">{signs.map(sign => {
      const id = str(sign.id), on = living ? id === current : id === choice;
      return <div key={id} className={on ? 'setup-trait setup-trait-on' : 'setup-trait'}>
        <div className="setup-trait-head">{/^[\w-]+\.png$/.test(str(sign.image)) && <img className="setup-chart-glyph" src={str(sign.image)} width={48} height={48} alt="" />}<strong>{str(sign.name)}</strong><Pill tone="muted">{str(sign.season)}</Pill>{on && <Pill tone="ready">{living ? 'Yours' : 'Chosen'}</Pill>}</div>
        <p className="setup-trait-desc">{str(sign.calling)}</p>
        <p className="setup-chart-up">{str(sign.strengths)}</p>
        <p className="setup-chart-down">{str(sign.weaknesses)}</p>
        {!living && <div className="setup-trait-foot"><Action ui={ui} action="birth_chart" value={id} selected={on} disabled={!verified}>{on ? 'Chosen' : 'Choose'}</Action></div>}
      </div>;
    })}</div>
  </>;
}

function Settings({ ui }: { ui: UI }) {
  const s = ui.data.settings ?? {};
  const same = (values: unknown): [string, string][] => list(values).map(value => [str(value), str(value)]);
  return <>
    <Section title="Display"><Rows>
      <Row label="HUD style"><Choice ui={ui} action="ui_style" value={s.ui_style} label="HUD style" options={same(s.ui_styles)} /></Row>
      <Row label="Mouse cursor"><Choice ui={ui} action="cursor" value={s.cursor} label="Mouse cursor" options={same(s.cursors)} /></Row>
      <Row label="Frames per second"><Choice ui={ui} action="client_fps" value={Number(s.client_fps)} label="Frames per second" options={list(s.fps_choices).map(fps => [Number(fps), String(fps)])} />
        <p className="kit-hint">30 or 60 may help slower computers.</p></Row>
      {s.tutorial != null && <Row label="New-player tutorial" buttons={<Action ui={ui} action="reset_tutorial">Reset progress</Action>}>{str(s.tutorial)}</Row>}
    </Rows></Section>
    <Section title="Controls and HUD"><Rows>
      <Row label="Step one tile per tap"><Choice ui={ui} action="tap_step" value={s.tap_step ? 1 : 0} label="Step one tile per tap" options={[[1, 'On'], [0, 'Off']]} />
        <p className="kit-hint">On: a quick tap of a movement key moves you exactly one tile, and holding it still glides. Off: you stop where you let go. Your HUD has a footprint button for this too.</p></Row>
      <Row label="Name under the mouse"><Choice ui={ui} action="hover_text" value={Number(s.hover_text) || 0} label="Name under the mouse" options={[[1, 'At the pointer'], [2, 'Bottom of screen'], [0, 'Hidden']]} /></Row>
      <Row label="Name size"><Choice ui={ui} action="hover_text_scale" value={s.hover_text_scale} label="Name size" options={same(s.scales)} /></Row>
      <Row label="HUD size"><Choice ui={ui} action="hud_scale" value={s.hud_scale} label="HUD size" options={same(s.scales)} /></Row>
      <Row label="HUD layout" buttons={<><Action ui={ui} action="edit_hud_layout">{s.hud_editing ? 'Save layout' : 'Edit layout'}</Action><Action ui={ui} action="reset_hud_layout">Reset</Action></>}>
        Move, resize and lock the buttons on your screen. Needs a character in the world.</Row>
      <Row label="Key bindings" buttons={<Action ui={ui} action="keybindings">Change keys</Action>}>Choose the keys for actions.</Row>
    </Rows></Section>
    <Section title="Sound and chat"><Rows>{list(s.toggles).map(toggle => <Row key={str(toggle.key)} label={str(toggle.label)}>
      <span className="kit-choice" role="group" aria-label={str(toggle.label)}>
        <Action ui={ui} action="toggle_on" value={str(toggle.key)} selected={!!toggle.on}>{str(toggle.on_label)}</Action>
        <Action ui={ui} action="toggle_off" value={str(toggle.key)} selected={!toggle.on}>{str(toggle.off_label)}</Action>
      </span></Row>)}</Rows></Section>
  </>;
}
