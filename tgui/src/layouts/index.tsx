import type { CSSProperties, PropsWithChildren, ReactNode } from 'react';

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

export const Window = Object.assign(
  ({ buttons, children }: WindowProps) => (
    <section className="wiremod-window" aria-label="Wiremod circuit editor">
      <div className="wiremod-window__buttons">{buttons}</div>
      {children}
    </section>
  ),
  { Content },
);
