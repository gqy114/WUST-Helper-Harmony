import { decodeHtmlEntities } from '../net/CampusWallApi';

interface RichTextRun {
  text: string;
  bold: boolean;
  italic: boolean;
  underline: boolean;
  strike: boolean;
}

function parseRichText(value: string): RichTextRun[] {
  const source = decodeHtmlEntities(value || '');
  const runs: RichTextRun[] = [];
  const tagPattern = /<[^>]+>/g;
  let boldDepth = 0;
  let italicDepth = 0;
  let underlineDepth = 0;
  let strikeDepth = 0;
  let cursor = 0;

  const append = (text: string): void => {
    if (!text) return;
    const bold = boldDepth > 0;
    const italic = italicDepth > 0;
    const underline = underlineDepth > 0;
    const strike = strikeDepth > 0;
    const last = runs.length > 0 ? runs[runs.length - 1] : undefined;
    if (last && last.bold === bold && last.italic === italic && last.underline === underline && last.strike === strike) {
      last.text += text;
    } else {
      runs.push({ text, bold, italic, underline, strike });
    }
  };

  const appendNewline = (): void => {
    if (runs.length === 0) return;
    const last = runs[runs.length - 1];
    if (!last.text.endsWith('\n')) append('\n');
  };

  let match: RegExpExecArray | null = tagPattern.exec(source);
  while (match) {
    append(source.substring(cursor, match.index));
    const tag = match[0].toLowerCase();
    const closing = tag.startsWith('</');
    if (/^<\/?(?:b|strong)\b/.test(tag)) boldDepth = Math.max(0, boldDepth + (closing ? -1 : 1));
    else if (/^<\/?(?:i|em)\b/.test(tag)) italicDepth = Math.max(0, italicDepth + (closing ? -1 : 1));
    else if (/^<\/?u\b/.test(tag)) underlineDepth = Math.max(0, underlineDepth + (closing ? -1 : 1));
    else if (/^<\/?(?:s|strike|del)\b/.test(tag)) strikeDepth = Math.max(0, strikeDepth + (closing ? -1 : 1));
    else if (/^<br\b/.test(tag) || (/^<\/?(?:p|div)\b/.test(tag) && closing)) appendNewline();
    cursor = match.index + match[0].length;
    match = tagPattern.exec(source);
  }
  append(source.substring(cursor));
  if (runs.length === 0) runs.push({ text: source, bold: false, italic: false, underline: false, strike: false });
  runs[0].text = runs[0].text.replace(/^\s+/, '');
  runs[runs.length - 1].text = runs[runs.length - 1].text.replace(/\s+$/, '');
  return runs.filter((run: RichTextRun) => run.text.length > 0);
}

@Component
export struct CampusRichText {
  @Prop content: string = '';
  @Prop fontSize: number = 18;
  @Prop textColor: string = '#333333';
  @Prop baseBold: boolean = false;
  @Prop lineHeight: number = 28;

  build() {
    Text() {
      ForEach(parseRichText(this.content), (run: RichTextRun) => {
        Span(run.text)
          .fontWeight(this.baseBold || run.bold ? FontWeight.Bold : FontWeight.Normal)
          .fontStyle(run.italic ? FontStyle.Italic : FontStyle.Normal)
          .decoration({ type: run.underline ? TextDecorationType.Underline :
            (run.strike ? TextDecorationType.LineThrough : TextDecorationType.None) })
      }, (run: RichTextRun, index: number) => `${index}-${run.text}-${run.bold}-${run.italic}-${run.underline}-${run.strike}`)
    }.width('100%').fontSize(this.fontSize).fontColor(this.textColor).lineHeight(this.lineHeight)
  }
}
