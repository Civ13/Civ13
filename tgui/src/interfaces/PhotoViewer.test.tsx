import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { PhotoViewer } from './PhotoViewer';
import type { Data, ScreenProps } from '../types';
afterEach(cleanup);
const ui = (data: Data = {}): ScreenProps => ({ template: 'photo_viewer.tmpl', interactive: false, act: vi.fn(),
  data: { name: 'Sand &amp; sea', image: 'tmp_photo_12.png', width: 192, scribble: 'A &quot;fictional&quot; shore &amp; boat.', ...data } });
describe('Photo reader', () => {
  it('shows the existing filename, pixel dimensions and decoded inert caption', () => {
    render(<PhotoViewer {...ui()} />);
    expect(screen.getByRole('heading').textContent).toBe('Sand & sea');
    const image = screen.getByRole('img') as HTMLImageElement;
    expect(image.getAttribute('src')).toBe('tmp_photo_12.png'); expect(image.width).toBe(192);
    expect(screen.getByText('A "fictional" shore & boat.').tagName).toBe('EM');
  });
  it('rejects every filename outside the existing numeric photo basename', () => {
    const { rerender } = render(<PhotoViewer {...ui()} />);
    for (const image of ['https://example.com/photo.png', '../tmp_photo_1.png', 'byond://?src=x', 'tmp_photo_1.png?x=1', 'tmp_photo_1.png" onerror="x', 'tmp_photo_a.png', 'TMP_PHOTO_1.PNG']) {
      rerender(<PhotoViewer {...ui({ image })} />);
      expect(screen.queryByRole('img')).toBeNull(); expect(screen.getByText('No captured image is available.')).toBeTruthy();
    }
  });
  it('renders hostile labels and captions as text without new elements or handlers', () => {
    const { container } = render(<PhotoViewer {...ui({ name: '&lt;script&gt;name&lt;/script&gt;', scribble: '&lt;img src=x onerror=alert(1)&gt;' })} />);
    expect(screen.getByRole('heading').textContent).toBe('<script>name</script>');
    expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();
    expect(container.querySelectorAll('script,[onerror]')).toHaveLength(0); expect(screen.getAllByRole('img')).toHaveLength(1);
  });
  it('replaces the image/caption on a new snapshot and clears missing content', () => {
    const { rerender } = render(<PhotoViewer {...ui()} />);
    rerender(<PhotoViewer {...ui({ name: 'Second', image: 'tmp_photo_0.png', scribble: '' })} />);
    expect(screen.getByRole('img').getAttribute('src')).toBe('tmp_photo_0.png'); expect(screen.queryByText(/fictional/)).toBeNull();
    rerender(<PhotoViewer {...ui({ name: '', image: '', scribble: '' })} />);
    expect(screen.queryByRole('img')).toBeNull(); expect(screen.getByRole('heading').textContent).toBe('Photograph');
    expect(screen.queryByText('Written on the back:')).toBeNull();
  });
  it('bounds display size while preserving the four normal camera sizes', () => {
    const { rerender } = render(<PhotoViewer {...ui()} />);
    for (const width of [64, 192, 320, 448]) {
      rerender(<PhotoViewer {...ui({ width })} />); expect((screen.getByRole('img') as HTMLImageElement).width).toBe(width);
    }
    for (const [width, expected] of [[-5, 64], [10000, 448], ['invalid', 192], [Infinity, 192]] as const) {
      rerender(<PhotoViewer {...ui({ width })} />); expect((screen.getByRole('img') as HTMLImageElement).width).toBe(expected);
    }
  });
  it('has no domain controls or action path even if the transport marks it interactive', () => {
    const props = { ...ui({ desc: 'Hidden description', creator: 'Hidden creator' }), interactive: true };
    const { container } = render(<PhotoViewer {...props} />); fireEvent.click(screen.getByRole('img'));
    expect(props.act).not.toHaveBeenCalled(); expect(container.querySelectorAll('button,a,input,select,textarea')).toHaveLength(0);
    expect(container.textContent).not.toContain('Hidden description'); expect(container.textContent).not.toContain('Hidden creator');
  });
});
