import { Section, NoticeBox } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { Action, list, text } from './common';
export function Warehouse({ data }: ScreenProps) {
  return <Section title="Warehouse Inventory">{list(data.items).length ? <table className="inventory"><thead><tr><th>Item Name</th><th>Quantity</th></tr></thead><tbody>{list(data.items).map((item, i) => <tr key={i}><td>{text(item.name)}</td><td>{item.amount}</td></tr>)}</tbody></table> : <NoticeBox>The warehouse is currently empty.</NoticeBox>}</Section>;
}
export function Chemistry(ui: ScreenProps) {
  const { data } = ui;
  const vessel = data.glass ? 'Glass' : 'Beaker';
  return <><Section title="Dispense amount">{[5, 10, 20, 30, 40].map(amount => <Action key={amount} ui={ui} action="amount" value={amount} selected={Number(data.amount) === amount}>{amount}</Action>)}</Section>
    <Section title={data.glass ? 'Drink Dispenser' : 'Chemical Dispenser'}>{list(data.chemicals).map((chemical, i) => {
      const commands = chemical.commands ?? {};
      const action = Object.keys(commands)[0];
      return action ? <Action key={i} ui={ui} action={action} value={commands[action]} params={commands}>{text(chemical.title)}</Action> : null;
    })}</Section>
    <Section title={`${vessel} contents`} buttons={<Action ui={ui} action="ejectBeaker" disabled={!data.isBeakerLoaded}>Eject {vessel}</Action>}>
      {data.isBeakerLoaded ? <><p>Volume: {data.beakerCurrentVolume} / {data.beakerMaxVolume}</p>{list(data.beakerContents).length ? list(data.beakerContents).map((item, i) => <p key={i}>{item.volume} units of {text(item.name)}</p>) : <NoticeBox>{vessel} is empty</NoticeBox>}</> : <NoticeBox>No {vessel.toLowerCase()} loaded</NoticeBox>}
    </Section></>;
}
export function Appearance(ui: ScreenProps) {
  const { data } = ui;
  const choices = [
    ['change_race', 'Species', 'species', 'specimen', 'specimen', 'race', 'specimen'],
    ['change_gender', 'Gender', 'genders', 'gender_name', 'gender_key', 'gender', 'gender'],
    ['change_hair', 'Hair styles', 'hair_styles', 'hairstyle', 'hairstyle', 'hair', 'hair_style'],
    ['change_facial_hair', 'Facial hair styles', 'facial_hair_styles', 'facialhairstyle', 'facialhairstyle', 'facial_hair', 'facial_hair_style'],
  ];
  const colors = ['eye_color', 'skin_tone', 'skin_color', 'hair_color', 'facial_hair_color'];
  return <>{choices.map(([flag, title, source, label, key, action, selected]) => !!data[flag] && <Section key={flag} title={title}>{list(data[source]).map((item, i) => <Action key={i} ui={ui} action={action} value={item[key]} selected={data[selected] === item[key]}>{text(item[label])}</Action>)}</Section>)}
    {colors.some(color => data[`change_${color}`]) && <Section title="Colors">{colors.map(color => !!data[`change_${color}`] && <Action key={color} ui={ui} action={color}>Change {color.replaceAll('_', ' ')}</Action>)}</Section>}</>;
}
export function Vending(ui: ScreenProps) {
  const { data, template } = ui;
  const sales = template !== 'vending_machine.tmpl';
  return <div className={data.modern ? 'modern-vending' : ''}>
    {template === 'vending_machine2.tmpl' && <h2>{text(data.company)}</h2>}
    {sales && <Section title={`Money deposited${data.currency_name ? ` (${text(data.currency_name)})` : ''}`}><Action ui={ui} action="remove_money">{data.moneyin} {text(data.currency_short)}</Action></Section>}
    {Number(data.mode) === 0 ? <Section title="Items available">{list(data.products).length ? list(data.products).map((product, i) => <div className="product" key={i}><Action ui={ui} action="vend" value={product.key} disabled={!(product.amount > 0)}>{product.price > 0 ? `Buy (${product.price}${sales ? ` ${text(data.currency_short)}` : ''})` : 'Vend'}</Action><span style={{ color: typeof product.color === 'string' ? product.color : undefined }}>{text(product.name)}</span> ({product.amount || 'NONE LEFT'})</div>) : <NoticeBox>No items available!</NoticeBox>}</Section> : Number(data.mode) === 1 && <Section title="Item selected"><p>{text(data.product)}</p><p>{template === 'vending_machine_gulag.tmpl' ? 'Price' : 'Charge'}: {data.price}</p><NoticeBox danger={!!data.message_err}>{text(data.message)}</NoticeBox><Action ui={ui} action="cancelpurchase">Cancel</Action></Section>}
    {!sales && !!data.coin && <Section title="Coin deposited"><Action ui={ui} action="remove_coin">{text(data.coin)}</Action></Section>}
    {template !== 'vending_machine_gulag.tmpl' && !!data.panel && <Section title="Maintenance panel">Speaker: <Action ui={ui} action="togglevoice">{data.speaker ? 'Enabled' : 'Disabled'}</Action></Section>}
  </div>;
}
