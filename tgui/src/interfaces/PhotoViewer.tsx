import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { text } from './common';

export function PhotoViewer({ data }: ScreenProps) {
  const image = typeof data.image === 'string' && /^tmp_photo_[0-9]+\.png$/.test(data.image) ? data.image : '';
  const width = Number(data.width);
  const displayWidth = Number.isFinite(width) ? Math.max(64, Math.min(448, width)) : 192;
  return <Section title={text(data.name) || 'Photograph'}>
    <div className="photo-viewer">
      {image ? <img src={image} width={displayWidth} alt="Photograph" /> : <NoticeBox>No captured image is available.</NoticeBox>}
      {!!data.scribble && <p>Written on the back:<br /><em>{text(data.scribble)}</em></p>}
    </div>
  </Section>;
}
