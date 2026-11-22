import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen } from '@testing-library/react';
import { render } from '../testing';
import type { Data, ScreenProps } from '../types';
import { WiremodCircuit } from './WiremodCircuit';

afterEach(cleanup);

const ui = (data: Data = {}): ScreenProps => ({
  template: 'wiremod_circuit.tmpl',
  interactive: true,
  act: vi.fn(),
  data: {
    display_name: 'Integrated circuit',
    grid_mode: 1,
    screen_x: 0,
    screen_y: 0,
    component_catalog: [
      {
        type: '/obj/item/circuit_component/operator/arithmetic',
        name: 'Arithmetic',
        description: 'Performs arithmetic.',
        category: 'Math',
        input_ports: [{ name: 'A', type: 'number', color: 'green' }],
        output_ports: [{ name: 'Result', type: 'number', color: 'green' }],
      },
    ],
    components: [
      {
        // Ids are the circuit's own and differ from the place in the list:
        // these two are what is left after other components were removed.
        id: 4,
        type: '/obj/item/circuit_component/operator/arithmetic',
        name: 'Arithmetic',
        description: 'Performs arithmetic.',
        category: 'Math',
        removable: 1,
        x: 30,
        y: 30,
        input_ports: [],
        output_ports: [
          {
            name: 'Result',
            type: 'number',
            color: 'green',
            ref: 'output-4-1',
          },
        ],
      },
      {
        id: 9,
        type: '/obj/item/circuit_component/operator/arithmetic',
        name: 'Arithmetic',
        description: 'Performs arithmetic.',
        category: 'Math',
        removable: 1,
        x: 180,
        y: 80,
        input_ports: [
          {
            name: 'A',
            type: 'number',
            color: 'green',
            ref: 'input-9-1',
            connected_to: [],
            current_data: null,
          },
        ],
        output_ports: [],
      },
    ],
    ...data,
  },
});

describe('tgstation Wiremod circuit editor', () => {
  it('renders the original graph and connects compatible ports', () => {
    const props = ui();
    const view = render(<WiremodCircuit {...props} />);
    expect(view.container.querySelectorAll('.ObjectComponent')).toHaveLength(2);
    const ports = view.container.querySelectorAll('.ObjectComponent__Port');
    expect(ports).toHaveLength(2);

    fireEvent.mouseDown(ports[0], { button: 0, clientX: 100, clientY: 100 });
    fireEvent.mouseUp(ports[1], { button: 0, clientX: 200, clientY: 140 });

    expect(props.act).toHaveBeenLastCalledWith('add_connection', {
      input_port_id: 1,
      output_port_id: 1,
      input_component_id: 9,
      output_component_id: 4,
    });
  });

  it('names a component by its id, not its place, after a removal', () => {
    const props = ui();
    const first = (props.data.components as Data[])[0];
    const second = (props.data.components as Data[])[1];
    const view = render(<WiremodCircuit {...props} />);
    // The first component is removed: the second is now first in the list.
    view.rerender(
      <WiremodCircuit
        {...props}
        data={{ ...props.data, components: [second] }}
      />,
    );
    expect(view.container.querySelectorAll('.ObjectComponent')).toHaveLength(1);
    const titlebar = view.container.querySelector('.ObjectComponent__Titlebar');
    fireEvent.mouseDown(titlebar!, { button: 0, clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 110, clientY: 110 });
    fireEvent.mouseUp(titlebar!, { button: 0, clientX: 110, clientY: 110 });
    expect(props.act).toHaveBeenCalled();
    for (const call of (props.act as ReturnType<typeof vi.fn>).mock.calls) {
      if ('component_id' in (call[1] ?? {})) {
        expect(call[1].component_id).toBe(9);
      }
    }
    expect(first.id).toBe(4);
  });

  it('sends nothing for a component the server gave no id', () => {
    const props = ui();
    const components = (props.data.components as Data[]).map((component) => {
      const { id: _id, ...rest } = component;
      return rest;
    });
    const view = render(
      <WiremodCircuit {...props} data={{ ...props.data, components }} />,
    );
    const titlebar = view.container.querySelector('.ObjectComponent__Titlebar');
    fireEvent.mouseDown(titlebar!, { button: 0, clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 110, clientY: 110 });
    fireEvent.mouseUp(titlebar!, { button: 0, clientX: 110, clientY: 110 });
    expect(props.act).not.toHaveBeenCalled();
  });

  it('sends only text and numbers to the Civ13 window transport', () => {
    // The transport drops a whole request holding null or a boolean. Clearing
    // an input sends null with set_null: true in the upstream editor.
    const props = ui({
      components: [
        {
          id: 7,
          type: '/obj/item/circuit_component/operator/arithmetic',
          name: 'Arithmetic',
          description: 'Performs arithmetic.',
          category: 'Math',
          removable: 1,
          x: 30,
          y: 30,
          input_ports: [
            {
              name: 'A',
              type: 'number',
              color: 'green',
              ref: 'input-7-1',
              connected_to: [],
              current_data: 5,
            },
          ],
          output_ports: [],
        },
      ],
    });
    const view = render(<WiremodCircuit {...props} />);
    const clear = view.container.querySelector(
      '.ObjectComponent__Content .Button',
    );
    expect(clear).toBeTruthy();
    fireEvent.click(clear!);
    expect(props.act).toHaveBeenLastCalledWith('set_component_input', {
      component_id: 7,
      port_id: 1,
      set_null: 1,
    });
    for (const call of (props.act as ReturnType<typeof vi.fn>).mock.calls) {
      for (const value of Object.values(call[1] ?? {})) {
        expect(['string', 'number']).toContain(typeof value);
      }
    }
  });

  it('shows a dropdown for an input restricted to fixed choices', () => {
    const props = ui({
      components: [
        {
          id: 1,
          type: '/obj/item/circuit_component/operator/arithmetic',
          name: 'Arithmetic',
          description: 'Performs arithmetic.',
          category: 'Math',
          removable: 1,
          x: 30,
          y: 30,
          input_ports: [
            {
              name: 'Operation',
              type: 'option',
              color: 'violet',
              ref: 'input-1-1',
              connected_to: [],
              current_data: 'Add',
              datatype_data: ['Add', 'Subtract'],
            },
          ],
          output_ports: [],
        },
      ],
    });
    const view = render(<WiremodCircuit {...props} />);
    expect(view.container.querySelector('.Dropdown')).toBeTruthy();
    expect(view.container.textContent).toContain('Add');
  });

  it('marks an entity with a flag and shows what the input holds', () => {
    const target = (current_data: string | null) => ({
      id: 3,
      type: '/obj/item/circuit_component/direction',
      name: 'Direction',
      description: 'Finds a target.',
      category: 'Entity',
      removable: 1,
      x: 30,
      y: 30,
      input_ports: [
        {
          name: 'Target',
          type: 'entity',
          color: 'purple',
          ref: 'input-3-1',
          connected_to: [],
          current_data,
        },
      ],
      output_ports: [],
    });
    const props = ui({ components: [target(null)] });
    const view = render(<WiremodCircuit {...props} />);
    const mark = view.container.querySelector(
      '.ObjectComponent__Content .Button',
    );
    expect(mark?.textContent).toBe('Target');
    fireEvent.click(mark!);
    // The request says "mark", never what: the server takes what the player holds.
    expect(props.act).toHaveBeenLastCalledWith('set_component_input', {
      component_id: 3,
      port_id: 1,
      marked_atom: 1,
    });
    cleanup();
    const marked = render(
      <WiremodCircuit {...ui({ components: [target('<b>iron key</b>')] })} />,
    );
    const button = marked.container.querySelector(
      '.ObjectComponent__Content .Button',
    );
    expect(button?.textContent).toBe('Target: <b>iron key</b>');
    expect(marked.container.querySelector('.ObjectComponent__Content b')).toBeNull();
  });

  it('loads the Civ13 core catalog into the original component menu', async () => {
    const view = render(<WiremodCircuit {...ui({ components: [] })} />);
    const buttons = view.container.querySelectorAll(
      '.wiremod-window__buttons .Button',
    );
    fireEvent.click(buttons[1]);

    expect(await screen.findByText('Component Menu')).toBeTruthy();
    expect(await screen.findByText('Arithmetic')).toBeTruthy();
  });

  it('renders variables in the original variable menu', async () => {
    const view = render(
      <WiremodCircuit
        {...ui({
          components: [],
          variables: [
            { name: 'score', datatype: 'number', color: 'green', is_list: 0 },
          ],
          global_basic_types: ['number', 'boolean', 'string', 'any'],
        })}
      />,
    );
    const buttons = view.container.querySelectorAll(
      '.wiremod-window__buttons .Button',
    );
    fireEvent.click(buttons[0]);

    expect(await screen.findByText('Variable Options')).toBeTruthy();
    expect(screen.getByText('score')).toBeTruthy();
  });

  it('adapts zoomed pointer coordinates when dragging a circuit component', () => {
    const props = ui();
    const view = render(<WiremodCircuit {...props} />);
    const zoomPlane = view.container.querySelector<HTMLElement>(
      '.wiremod-window__content [style*="scale("]',
    );
    expect(zoomPlane).toBeTruthy();
    zoomPlane!.style.transform = 'translate(0px, 0px) scale(2)';
    const titlebar = view.container.querySelector(
      '.ObjectComponent__Titlebar',
    );
    expect(titlebar).toBeTruthy();

    fireEvent.mouseDown(titlebar!, { button: 0, clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 100, clientY: 100 });
    fireEvent.mouseMove(window, { clientX: 180, clientY: 160 });
    fireEvent.mouseUp(titlebar!, { button: 0, clientX: 180, clientY: 160 });

    expect(props.act).toHaveBeenCalledWith('set_component_coordinates', {
      component_id: 4,
      rel_x: 70,
      rel_y: 60,
    });
  });
});
