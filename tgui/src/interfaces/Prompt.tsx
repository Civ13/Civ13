import { Button, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { list, text } from './common';

// One prompt window per WWinput call. The answer is the 1-based index of the
// offered choice; the server maps it back and drops anything out of range.
export function Prompt({ data, act, interactive }: ScreenProps) {
  const choices = list(data.choices).map(choice => text(choice));
  return <Section>
    <p className="civ13-prompt-message">{text(data.message)}</p>
    <div className="civ13-prompt-choices">
      {choices.map((choice, index) => <Button key={index} disabled={!interactive}
        onClick={() => act('answer', { answer: index + 1 })}>{choice}</Button>)}
    </div>
  </Section>;
}
