import type { Data } from './types';

let componentCatalog: Data[] = [];
const gridBackground = new URL(
  './interfaces/IntegratedCircuit/grid_background.png',
  import.meta.url,
).href;

export const setWiremodComponentCatalog = (catalog: Data[]) => {
  componentCatalog = catalog;
};

export const resolveAsset = (path: string) => {
  if (path === 'grid_background.png') {
    return gridBackground;
  }
  if (path === 'circuit_components.json') {
    const json = encodeURIComponent(JSON.stringify(componentCatalog));
    return `data:application/json;charset=utf-8,${json}`;
  }
  return path;
};
