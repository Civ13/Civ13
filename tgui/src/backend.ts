import type { Data, Params } from './types';

type BackendState = {
  data: Data;
  act: (action: string, params?: Params) => void;
};

let backendState: BackendState = {
  data: {},
  act: () => {},
};

export const setBackendState = (data: Data, act: BackendState['act']) => {
  backendState = { data, act };
};

export const useBackend = () => backendState;
