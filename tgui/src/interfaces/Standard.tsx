import { Section, NoticeBox } from 'tgui-core/components';
import type { AppearanceData, ChemistryData, Flag, VendingData, WarehouseData } from '../data';
import type { ScreenProps } from '../types';
import { Action, list, str } from './common';
import { Choice, Pill, Row, Rows, SnapshotTable, cell } from './kit';
export function Warehouse({ data }: ScreenProps<WarehouseData>) {
  return <SnapshotTable label="Warehouse inventory" rows={data.items} empty="The warehouse is currently empty."
    columns={[{ label: 'Item Name', cell: cell('name') }, { label: 'Quantity', align: 'right', cell: cell('amount') }]} />;
}
export function Chemistry(ui: ScreenProps<ChemistryData>) {
  const { data } = ui;
  const vessel = data.glass ? 'Glass' : 'Beaker';
  const eject = <Action ui={ui} action="ejectBeaker" disabled={!data.isBeakerLoaded}>Eject {vessel}</Action>;
  return <><Section title="Amount per press">
      <Choice ui={ui} action="amount" value={Number(data.amount)} label="Units dispensed per press" options={[5, 10, 20, 30, 40].map(amount => [amount, String(amount)])} /> units
    </Section>
    <Section title={data.glass ? 'Drinks' : 'Reagents'}>{list(data.chemicals).map((chemical, i) => {
      return chemical.id ? <Action key={i} ui={ui} action="dispense" value={chemical.id}>{str(chemical.title)}</Action> : null;
    })}</Section>
    {data.isBeakerLoaded
      ? <SnapshotTable title={`${vessel} contents`} buttons={eject} label={`${vessel} contents`} rows={data.beakerContents} empty={`${vessel} is empty`}
          hint={`Holds ${data.beakerCurrentVolume} of ${data.beakerMaxVolume} units.`}
          columns={[{ label: 'Reagent', cell: cell('name') }, { label: 'Units', align: 'right', cell: cell('volume') }]} />
      : <Section title={`${vessel} contents`} buttons={eject}><NoticeBox>No {vessel.toLowerCase()} loaded</NoticeBox></Section>}</>;
}
export function Appearance(ui: ScreenProps<AppearanceData>) {
  const { data } = ui;
  const same = (rows: unknown[], field: string): [string, string][] => rows.map(row => [str((row as Record<string, unknown>)[field]), str((row as Record<string, unknown>)[field])]);
  const groups: { show?: Flag; title: string; action: string; current?: string; options: [string, string][] }[] = [
    { show: data.change_race, title: 'Species', action: 'race', current: data.specimen, options: same(list(data.species), 'specimen') },
    { show: data.change_gender, title: 'Gender', action: 'gender', current: data.gender, options: list(data.genders).map(row => [str(row.gender_key), str(row.gender_name)]) },
    { show: data.change_hair, title: 'Hair style', action: 'hair', current: data.hair_style, options: same(list(data.hair_styles), 'hairstyle') },
    { show: data.change_facial_hair, title: 'Facial hair', action: 'facial_hair', current: data.facial_hair_style, options: same(list(data.facial_hair_styles), 'facialhairstyle') },
  ];
  const colors: [Flag | undefined, string][] = [[data.change_eye_color, 'eye_color'], [data.change_skin_tone, 'skin_tone'], [data.change_skin_color, 'skin_color'],
    [data.change_hair_color, 'hair_color'], [data.change_facial_hair_color, 'facial_hair_color']];
  return <>{groups.map(group => !!group.show && <Section key={group.action} title={group.title}>
      <Choice ui={ui} action={group.action} value={group.current} label={group.title} options={group.options} />
    </Section>)}
    {colors.some(([show]) => show) && <Section title="Colors">{colors.map(([show, action]) => !!show && <Action key={action} ui={ui} action={action}>Change {action.replaceAll('_', ' ')}</Action>)}</Section>}</>;
}
export function Vending(ui: ScreenProps<VendingData>) {
  const { data, template } = ui;
  const sales = template !== 'vending_machine.tmpl';
  const unit = sales && data.currency_short ? ` ${str(data.currency_short)}` : '';
  return <div className={data.modern ? 'modern-vending' : ''}>
    {template === 'vending_machine2.tmpl' && <h2>{str(data.company)}</h2>}
    {sales && <Section title="Payment"><Rows>
      <Row label={`Deposited${data.currency_name ? ` (${str(data.currency_name)})` : ''}`} buttons={<Action ui={ui} action="remove_money" disabled={!(Number(data.moneyin) > 0)}>Take it back</Action>}>{data.moneyin}{unit}</Row>
    </Rows></Section>}
    {Number(data.mode) === 0 ? <SnapshotTable title="Goods" label="Goods for sale" rows={data.products} empty="Nothing is stocked."
      columns={[
        { label: 'Item', cell: product => <span style={{ color: typeof product.color === 'string' ? product.color : undefined }}>{str(product.name)}</span> },
        { label: 'In stock', align: 'right', cell: product => product.amount > 0 ? product.amount : <Pill tone="warn">Sold out</Pill> },
        { label: 'Price', align: 'right', cell: product => product.price > 0 ? `${product.price}${unit}` : 'Free' },
        { label: '', align: 'right', cell: product => <Action ui={ui} action="vend" value={product.key} disabled={!(product.amount > 0)}>{product.price > 0 ? 'Buy' : 'Take'}</Action> },
      ]} />
      : Number(data.mode) === 1 && <Section title="Your purchase"><Rows>
        <Row label="Item">{str(data.product)}</Row>
        <Row label={template === 'vending_machine_gulag.tmpl' ? 'Price' : 'Charge'}>{data.price}{unit}</Row>
      </Rows><NoticeBox danger={!!data.message_err}>{str(data.message)}</NoticeBox><Action ui={ui} action="cancelpurchase">Cancel</Action></Section>}
    {!sales && !!data.coin && <Section title="Payment"><Rows><Row label="Coin inserted" buttons={<Action ui={ui} action="remove_coin">Take it back</Action>}>{str(data.coin)}</Row></Rows></Section>}
    {template !== 'vending_machine_gulag.tmpl' && !!data.panel && <Section title="Maintenance panel"><Rows><Row label="Speaker" buttons={<Action ui={ui} action="togglevoice">{data.speaker ? 'Turn off' : 'Turn on'}</Action>}>{data.speaker ? 'On' : 'Off'}</Row></Rows></Section>}
  </div>;
}
