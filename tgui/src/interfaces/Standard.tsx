import { Section, NoticeBox } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { Action, list, text } from './common';
import { Choice, Pill, Row, Rows, SnapshotTable, cell } from './kit';
export function Warehouse({ data }: ScreenProps) {
  return <SnapshotTable label="Warehouse inventory" rows={data.items} empty="The warehouse is currently empty."
    columns={[{ label: 'Item Name', cell: cell('name') }, { label: 'Quantity', align: 'right', cell: cell('amount') }]} />;
}
export function Chemistry(ui: ScreenProps) {
  const { data } = ui;
  const vessel = data.glass ? 'Glass' : 'Beaker';
  const eject = <Action ui={ui} action="ejectBeaker" disabled={!data.isBeakerLoaded}>Eject {vessel}</Action>;
  return <><Section title="Amount per press">
      <Choice ui={ui} action="amount" value={Number(data.amount)} label="Units dispensed per press" options={[5, 10, 20, 30, 40].map(amount => [amount, String(amount)])} /> units
    </Section>
    <Section title={data.glass ? 'Drinks' : 'Reagents'}>{list(data.chemicals).map((chemical, i) => {
      return chemical.id ? <Action key={i} ui={ui} action="dispense" value={chemical.id}>{text(chemical.title)}</Action> : null;
    })}</Section>
    {data.isBeakerLoaded
      ? <SnapshotTable title={`${vessel} contents`} buttons={eject} label={`${vessel} contents`} rows={data.beakerContents} empty={`${vessel} is empty`}
          hint={`Holds ${data.beakerCurrentVolume} of ${data.beakerMaxVolume} units.`}
          columns={[{ label: 'Reagent', cell: cell('name') }, { label: 'Units', align: 'right', cell: cell('volume') }]} />
      : <Section title={`${vessel} contents`} buttons={eject}><NoticeBox>No {vessel.toLowerCase()} loaded</NoticeBox></Section>}</>;
}
export function Appearance(ui: ScreenProps) {
  const { data } = ui;
  const choices = [
    ['change_race', 'Species', 'species', 'specimen', 'specimen', 'race', 'specimen'],
    ['change_gender', 'Gender', 'genders', 'gender_name', 'gender_key', 'gender', 'gender'],
    ['change_hair', 'Hair style', 'hair_styles', 'hairstyle', 'hairstyle', 'hair', 'hair_style'],
    ['change_facial_hair', 'Facial hair', 'facial_hair_styles', 'facialhairstyle', 'facialhairstyle', 'facial_hair', 'facial_hair_style'],
  ];
  const colors = ['eye_color', 'skin_tone', 'skin_color', 'hair_color', 'facial_hair_color'];
  return <>{choices.map(([flag, title, source, label, key, action, selected]) => !!data[flag] && <Section key={flag} title={title}>
      <Choice ui={ui} action={action} value={data[selected]} label={title} options={list(data[source]).map(item => [item[key] as string, text(item[label])])} />
    </Section>)}
    {colors.some(color => data[`change_${color}`]) && <Section title="Colors">{colors.map(color => !!data[`change_${color}`] && <Action key={color} ui={ui} action={color}>Change {color.replaceAll('_', ' ')}</Action>)}</Section>}</>;
}
export function Vending(ui: ScreenProps) {
  const { data, template } = ui;
  const sales = template !== 'vending_machine.tmpl';
  const unit = sales && data.currency_short ? ` ${text(data.currency_short)}` : '';
  return <div className={data.modern ? 'modern-vending' : ''}>
    {template === 'vending_machine2.tmpl' && <h2>{text(data.company)}</h2>}
    {sales && <Section title="Payment"><Rows>
      <Row label={`Deposited${data.currency_name ? ` (${text(data.currency_name)})` : ''}`} buttons={<Action ui={ui} action="remove_money" disabled={!(Number(data.moneyin) > 0)}>Take it back</Action>}>{data.moneyin}{unit}</Row>
    </Rows></Section>}
    {Number(data.mode) === 0 ? <SnapshotTable title="Goods" label="Goods for sale" rows={data.products} empty="Nothing is stocked."
      columns={[
        { label: 'Item', cell: product => <span style={{ color: typeof product.color === 'string' ? product.color : undefined }}>{text(product.name)}</span> },
        { label: 'In stock', align: 'right', cell: product => product.amount > 0 ? product.amount : <Pill tone="warn">Sold out</Pill> },
        { label: 'Price', align: 'right', cell: product => product.price > 0 ? `${product.price}${unit}` : 'Free' },
        { label: '', align: 'right', cell: product => <Action ui={ui} action="vend" value={product.key} disabled={!(product.amount > 0)}>{product.price > 0 ? 'Buy' : 'Take'}</Action> },
      ]} />
      : Number(data.mode) === 1 && <Section title="Your purchase"><Rows>
        <Row label="Item">{text(data.product)}</Row>
        <Row label={template === 'vending_machine_gulag.tmpl' ? 'Price' : 'Charge'}>{data.price}{unit}</Row>
      </Rows><NoticeBox danger={!!data.message_err}>{text(data.message)}</NoticeBox><Action ui={ui} action="cancelpurchase">Cancel</Action></Section>}
    {!sales && !!data.coin && <Section title="Payment"><Rows><Row label="Coin inserted" buttons={<Action ui={ui} action="remove_coin">Take it back</Action>}>{text(data.coin)}</Row></Rows></Section>}
    {template !== 'vending_machine_gulag.tmpl' && !!data.panel && <Section title="Maintenance panel"><Rows><Row label="Speaker" buttons={<Action ui={ui} action="togglevoice">{data.speaker ? 'Turn off' : 'Turn on'}</Action>}>{data.speaker ? 'On' : 'Off'}</Row></Rows></Section>}
  </div>;
}
