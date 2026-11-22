import { type CSSProperties, type PropsWithChildren, type ReactNode, useContext } from 'react';
import { createPortal } from 'react-dom';
import { TitleBarSlot } from '../titlebar';

type WindowProps = PropsWithChildren<{
  buttons?: ReactNode;
  height?: number;
  width?: number;
}>;

type ContentProps = PropsWithChildren<{
  style?: CSSProperties;
}>;

const Content = ({ children, style }: ContentProps) => (
  <div className="wiremod-window__content" style={style}>
    {children}
  </div>
);

// With the window's own title bar, the editor's buttons sit in that bar, as
// they do upstream; the 32px strip under it keeps the canvas offset.
const Buttons = ({ children }: PropsWithChildren) => {
  const slot = useContext(TitleBarSlot);
  if (!slot) return <div className="wiremod-window__buttons">{children}</div>;
  return <>
    <div className="wiremod-window__buttons" />
    {createPortal(<div className="wiremod-titlebuttons">{children}</div>, slot)}
  </>;
};

export const Window = Object.assign(
  ({ buttons, children }: WindowProps) => (
    <section className="wiremod-window" aria-label="Wiremod circuit editor">
      <Buttons>{buttons}</Buttons>
      {children}
    </section>
  ),
  { Content },
);
