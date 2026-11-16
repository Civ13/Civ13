import { cloneElement, type ReactElement } from 'react';
import { render as mount } from '@testing-library/react';
import { decodeData, documentTemplates } from './state';
import type { ScreenProps } from './types';

// The app hands a screen its snapshot through updateState(), which decodes display
// text once. Tests that render a screen directly take the same step here.
// The same snapshot object stays the same decoded object, as it does in the app.
const seen = new WeakMap<object, object>();
function received(ui: ReactElement): ReactElement {
  const props = ui.props as Partial<ScreenProps>;
  if (!props.data || documentTemplates.has(String(props.template ?? ''))) return ui;
  if (!seen.has(props.data)) seen.set(props.data, decodeData(props.data));
  return cloneElement(ui as ReactElement<Partial<ScreenProps>>, { data: seen.get(props.data) });
}
export function render(ui: ReactElement) {
  const view = mount(received(ui));
  return { ...view, rerender: (next: ReactElement) => view.rerender(received(next)) };
}
