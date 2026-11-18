import { useEffect } from 'react';

import { setWiremodComponentCatalog } from '../assets';
import { setBackendState } from '../backend';
import type { Data, Params, ScreenProps } from '../types';
import { IntegratedCircuit } from './IntegratedCircuit/index.jsx';

type ZoomedMouseEvent = MouseEvent & {
  screenZoomX?: number;
  screenZoomY?: number;
};

const getPlaneZoom = () => {
  const plane = document.querySelector<HTMLElement>(
    '.wiremod-window__content [style*="scale("]',
  );
  const match = plane?.style.transform.match(/scale\(([^)]+)\)/);
  const zoom = Number(match?.[1]);
  return Number.isFinite(zoom) && zoom > 0 ? zoom : 1;
};

// The request fields in which the upstream editor names a component. It names
// one by its place in the component list (1 for the first); Civ13 names one by
// the id the circuit gave it, which stays the same when another is removed.
const COMPONENT_FIELDS = [
  'component_id',
  'input_component_id',
  'output_component_id',
];

export const WiremodCircuit = (props: ScreenProps) => {
  const catalog = Array.isArray(props.data.component_catalog)
    ? (props.data.component_catalog as Data[])
    : [];
  const components = Array.isArray(props.data.components)
    ? (props.data.components as Data[])
    : [];
  const data = {
    ...props.data,
    components,
    variables: Array.isArray(props.data.variables) ? props.data.variables : [],
    global_basic_types: Array.isArray(props.data.global_basic_types)
      ? props.data.global_basic_types
      : [],
    // Every component in the catalog can be placed: Civ13 has no printer designs.
    stored_designs: Object.fromEntries(
      catalog.map((component) => [component.type, true]),
    ),
    component_catalog: catalog,
  };
  const act = (action: string, params: Params = {}) => {
    // The Civ13 window transport carries text and numbers only: it drops a
    // whole request that holds null, so absent values are left out and
    // true/false travel as 1/0.
    const adjusted: Params = {};
    for (const [key, value] of Object.entries(params as Record<string, unknown>)) {
      if (value === null || value === undefined) continue;
      if (typeof value === 'boolean') adjusted[key] = value ? 1 : 0;
      else if (typeof value === 'number') {
        if (Number.isFinite(value)) adjusted[key] = value;
      } else adjusted[key] = String(value);
    }
    // The place is looked up in the list this click was made on, so a request
    // always carries the id of the component the player saw. A place with no
    // component behind it is not sent at all.
    for (const field of COMPONENT_FIELDS) {
      if (!(field in adjusted)) continue;
      const id = components[Number(adjusted[field]) - 1]?.id;
      if (typeof id !== 'number' || id < 1) return;
      adjusted[field] = id;
    }
    const content = document.querySelector<HTMLElement>(
      '.wiremod-window__content',
    );
    if (action === 'set_examined_component' && content) {
      const bounds = content.getBoundingClientRect();
      adjusted.x = Number(adjusted.x) - bounds.left;
      adjusted.y = Number(adjusted.y) - bounds.top;
    }
    props.act(action, adjusted);
  };

  setBackendState(data, act);
  setWiremodComponentCatalog(catalog);

  useEffect(() => {
    const addZoomedCoordinates = (event: MouseEvent) => {
      const zoom = getPlaneZoom();
      const adjusted = event as ZoomedMouseEvent;
      adjusted.screenZoomX = event.clientX / zoom || Number.EPSILON;
      adjusted.screenZoomY = event.clientY / zoom || Number.EPSILON;
    };
    window.addEventListener('mousemove', addZoomedCoordinates, true);
    return () =>
      window.removeEventListener('mousemove', addZoomedCoordinates, true);
  }, []);

  return <IntegratedCircuit />;
};
