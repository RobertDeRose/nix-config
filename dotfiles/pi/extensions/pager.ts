import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { copyToClipboard, getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Markdown, truncateToWidth as tuiTruncateToWidth, visibleWidth as tuiVisibleWidth } from "@earendil-works/pi-tui";

type MarkdownCtor = new (markdown: string, x: number, y: number, theme: any) => { render(width: number): string[] };
type KeyName = "escape" | "tab" | "enter" | "right" | "left" | "down" | "up" | "pageDown" | "pageUp" | "home" | "end" | "space";
const Key: Record<KeyName, KeyName> = {
  escape: "escape",
  tab: "tab",
  enter: "enter",
  right: "right",
  left: "left",
  down: "down",
  up: "up",
  pageDown: "pageDown",
  pageUp: "pageUp",
  home: "home",
  end: "end",
  space: "space",
};

const ANSI_PATTERN = /\u001b\][^\u0007]*(?:\u0007|\u001b\\)|\u001b\[[0-?]*[ -\/]*[@-~]/g;
const ANSI_PREFIX_PATTERN = /^(?:\u001b\][^\u0007]*(?:\u0007|\u001b\\)|\u001b\[[0-?]*[ -\/]*[@-~])/;

function normalizeMarkdownInput(s: string): string {
  return s.replace(/\r\n?/g, "\n");
}

function sanitizeFrameLine(s: string): string {
  let out = "";

  for (let i = 0; i < s.length;) {
    const ansi = ANSI_PREFIX_PATTERN.exec(s.slice(i));
    if (ansi) {
      out += ansi[0];
      i += ansi[0].length;
      continue;
    }

    const codePoint = s.codePointAt(i);
    if (codePoint === undefined) break;
    const char = String.fromCodePoint(codePoint);
    i += char.length;

    if (char === "\r" || char === "\n") out += " ";
    else if (char === "\t") out += "  ";
    else if ((codePoint >= 0x00 && codePoint <= 0x1f) || codePoint === 0x7f) continue;
    else out += char;
  }

  return out;
}

function stripAnsi(s: string): string {
  return s.replace(ANSI_PATTERN, "");
}

function visibleWidth(s: string): number {
  return tuiVisibleWidth(sanitizeFrameLine(s));
}

function truncateToWidth(s: string, width: number, ellipsis = ""): string {
  return tuiTruncateToWidth(sanitizeFrameLine(s), width, ellipsis);
}

const KEY_SEQUENCES: Record<KeyName, readonly string[]> = {
  escape: ["\u001b", "esc"],
  tab: ["\t", "tab"],
  enter: ["\r", "\n", "enter", "return"],
  right: ["\u001b[C", "\u001bOC", "right"],
  left: ["\u001b[D", "\u001bOD", "left"],
  down: ["\u001b[B", "\u001bOB", "down"],
  up: ["\u001b[A", "\u001bOA", "up"],
  pageDown: ["\u001b[6~", "pageDown"],
  pageUp: ["\u001b[5~", "pageUp"],
  home: ["\u001b[H", "\u001b[1~", "\u001bOH", "home"],
  end: ["\u001b[F", "\u001b[4~", "\u001bOF", "end"],
  space: [" ", "space"],
};

const CSI_KEY_NAMES: Record<string, KeyName> = { A: "up", B: "down", C: "right", D: "left", F: "end", H: "home" };
const CSI_TILDE_KEY_NAMES: Record<number, KeyName> = { 1: "home", 4: "end", 5: "pageUp", 6: "pageDown" };

function parseKeyName(data: string): KeyName | undefined {
  for (const [name, sequences] of Object.entries(KEY_SEQUENCES) as [KeyName, readonly string[]][]) {
    if (sequences.includes(data)) return name;
  }
  const csiFinal = /^\u001b\[(?:\d+(?:;[\d:]+)*)?([A-DFH])$/.exec(data);
  if (csiFinal) return CSI_KEY_NAMES[csiFinal[1]!];
  const csiTilde = /^\u001b\[(\d+)(?:;[\d:]+)?~$/.exec(data);
  if (csiTilde) return CSI_TILDE_KEY_NAMES[Number(csiTilde[1])];
  return undefined;
}

function matchesKey(data: string, key: KeyName): boolean {
  return parseKeyName(data) === key;
}

function decodePrintableKey(data: string): string | undefined {
  if (data.length === 1 && data >= " " && data !== "\u007f") return data;
  const kitty = /^\u001b\[(\d+)(?:;[\d:]+)?u$/.exec(data);
  if (kitty) {
    const codepoint = Number(kitty[1]);
    if (Number.isFinite(codepoint) && codepoint >= 32) {
      try { return String.fromCodePoint(codepoint); } catch { return undefined; }
    }
  }
  const modifyOtherKeys = /^\u001b\[27;(\d+);(\d+)~$/.exec(data);
  if (modifyOtherKeys) {
    const modifier = Number(modifyOtherKeys[1]) - 1;
    const codepoint = Number(modifyOtherKeys[2]);
    if ((modifier & ~1) === 0 && Number.isFinite(codepoint) && codepoint >= 32) {
      try { return String.fromCodePoint(codepoint); } catch { return undefined; }
    }
  }
  return undefined;
}

type ContentBlock = { type?: string; text?: string };
type Heading = {
  level: number;
  title: string;
  sourceLine: number;
  renderLine: number;
  number?: string;
  explicitNumber?: string;
};
export type CodeBlock = {
  code: string;
  language?: string;
  sourceLine: number;
  renderLine: number;
  renderEndLine: number;
};
type Rendered = { lines: string[]; headings: Heading[]; codeBlocks: CodeBlock[] };

const MIN_TOC_TERMINAL_WIDTH = 100;
const MAX_TOC_WIDTH = 32;

function extractText(content: unknown): string {
  if (typeof content === "string") return content;
  if (!Array.isArray(content)) return "";
  return content
    .map((part) => {
      const block = part as ContentBlock;
      return block?.type === "text" && typeof block.text === "string" ? block.text : "";
    })
    .filter(Boolean)
    .join("\n\n");
}

function padRight(s: string, width: number): string {
  return s + " ".repeat(Math.max(0, width - visibleWidth(s)));
}

function isFence(line: string): boolean {
  return /^\s*(```|~~~)/.test(line);
}

export function extractFencedCodeBlocks(markdown: string): CodeBlock[] {
  const source = normalizeMarkdownInput(markdown).split("\n");
  const blocks: CodeBlock[] = [];

  for (let i = 0; i < source.length; i++) {
    const opening = /^ {0,3}(`{3,}|~{3,})(.*)$/.exec(source[i]!);
    if (!opening) continue;

    const marker = opening[1]!;
    const language = opening[2]!.trim().split(/\s+/, 1)[0] || undefined;
    const closing = new RegExp(`^ {0,3}${marker[0]}{${marker.length},}\\s*$`);
    let end = i + 1;
    while (end < source.length && !closing.test(source[end]!)) end++;

    blocks.push({
      code: source.slice(i + 1, end).join("\n"),
      language,
      sourceLine: i,
      renderLine: -1,
      renderEndLine: -1,
    });
    i = end;
  }

  return blocks;
}

function locateRenderedCodeBlocks(lines: string[], blocks: CodeBlock[]): void {
  let blockIndex = 0;
  let opening = true;

  for (let i = 0; i < lines.length && blockIndex < blocks.length; i++) {
    const line = stripAnsi(lines[i]!).trimEnd();
    if (!line.startsWith("```")) continue;

    if (opening) {
      blocks[blockIndex]!.renderLine = i;
    } else {
      blocks[blockIndex]!.renderEndLine = i;
      blockIndex++;
    }
    opening = !opening;
  }
}

function headingFromLine(line: string): { level: number; title: string } | null {
  const match = /^(#{1,6})\s+(.+?)\s*#*\s*$/.exec(line);
  if (!match) return null;
  return { level: match[1]!.length, title: match[2]!.trim() };
}

function parseHeadingNumber(title: string): { explicitNumber?: string; title: string } {
  // Match common leading numbering: "1 Title", "1. Title", "1.1 Title", "1.1.1) Title".
  const match = /^\s*(\d+(?:\.\d+)*)(?:[\.\)\-])?\s+(.+?)\s*$/.exec(title);
  if (!match) return { title: title.trim() };
  return { explicitNumber: match[1], title: match[2]!.trim() };
}

function normalizeSectionMarkdown(text: string): string {
  const lines = normalizeMarkdownInput(text).split("\n");
  let inCode = false;

  return lines
    .map((line) => {
      if (isFence(line)) {
        inCode = !inCode;
        return line;
      }
      if (inCode) return line;

      const heading = headingFromLine(line);
      if (!heading || heading.level < 3) return line;

      const parsed = parseHeadingNumber(heading.title);
      const title = parsed.explicitNumber ? `${parsed.explicitNumber} ${parsed.title}` : parsed.title;
      return `**${title}**`;
    })
    .join("\n");
}

function renderMarkdown(markdown: string, width: number, Markdown: MarkdownCtor, mdTheme: any): Rendered {
  const source = normalizeMarkdownInput(markdown).trimEnd().split("\n");
  const headings: Heading[] = [];
  const sections: { start: number; end: number; headingIndex?: number }[] = [];
  let inCode = false;
  let currentStart = 0;
  let currentHeadingIndex: number | undefined;

  for (let i = 0; i < source.length; i++) {
    const raw = source[i]!;
    if (isFence(raw)) {
      inCode = !inCode;
      continue;
    }
    if (inCode) continue;

    const heading = headingFromLine(raw);
    if (!heading) continue;

    if (i > currentStart || currentHeadingIndex !== undefined) {
      sections.push({ start: currentStart, end: i, headingIndex: currentHeadingIndex });
    }

    const headingIndex = headings.length;
    const parsed = parseHeadingNumber(heading.title);
    headings.push({ ...heading, ...parsed, sourceLine: i, renderLine: 0 });
    currentStart = i;
    currentHeadingIndex = headingIndex;
  }

  sections.push({ start: currentStart, end: source.length, headingIndex: currentHeadingIndex });

  const lines: string[] = [];
  for (const section of sections) {
    if (section.headingIndex !== undefined) {
      headings[section.headingIndex]!.renderLine = lines.length;
    }

    const text = source.slice(section.start, section.end).join("\n");
    if (!text.trim()) continue;

    if (lines.length > 0 && lines[lines.length - 1] !== "") {
      lines.push("");
    }

    const rendered = new Markdown(normalizeSectionMarkdown(text), 0, 0, mdTheme).render(width);
    lines.push(...rendered);
  }

  const codeBlocks = extractFencedCodeBlocks(markdown);
  locateRenderedCodeBlocks(lines, codeBlocks);

  if (headings.length === 0) {
    headings.push({ level: 1, title: "Response", sourceLine: 0, renderLine: 0, number: "1" });
  }

  // Compute hierarchical numbering for levels 1-3. If the heading already has
  // a visible number, keep it and sync the counters from it. Otherwise generate
  // the next number at that heading level.
  const counters: number[] = [];
  for (const h of headings) {
    const lvl = Math.min(3, h.level);

    if (h.explicitNumber) {
      const parts = h.explicitNumber.split(".").map((p) => Number(p)).filter((n) => Number.isFinite(n) && n > 0);
      h.number = h.explicitNumber;
      for (let j = 0; j < Math.min(3, parts.length); j++) counters[j] = parts[j]!;
      for (let j = Math.min(3, parts.length); j < 3; j++) counters[j] = 0;
      continue;
    }

    counters[lvl - 1] = (counters[lvl - 1] || 0) + 1;
    for (let j = lvl; j < 3; j++) counters[j] = 0;
    h.number = counters.slice(0, lvl).filter((n) => n > 0).join(".");
  }

  return { lines, headings, codeBlocks };
}

export class MarkdownPager {
  private scroll = 0;
  private selectedHeading = 0;
  private focus: "body" | "toc" = "body";
  private cachedWidth = 0;
  private rendered: Rendered = { lines: [], headings: [], codeBlocks: [] };
  private expandedDepthByTop = new Map<string, number>();
  private selectedCodeBlock = 0;
  private closed = false;
  private copyFeedback?: { index: number; status: "copied" | "failed" };
  private copyTimer: NodeJS.Timeout | null = null;
  private numBuffer = "";
  private numTimer: NodeJS.Timeout | null = null;

  constructor(
    private markdown: string,
    private theme: any,
    private closePager: () => void,
    private requestRender: () => void,
    private reservedRows: number,
    private Markdown: MarkdownCtor,
    private mdTheme: any,
    private copyText: (text: string) => Promise<void> = copyToClipboard,
  ) {}

  private close() {
    this.closed = true;
    if (this.numTimer) {
      clearTimeout(this.numTimer);
      this.numTimer = null;
    }
    if (this.copyTimer) {
      clearTimeout(this.copyTimer);
      this.copyTimer = null;
    }
    this.numBuffer = "";
    this.closePager();
  }

  private bodyHeight(): number {
    // Use the whole terminal for the pager frame. The frame itself consumes one
    // top and one bottom border row; any lower editor/footer chrome is hidden
    // while the pager is open.
    return Math.max(0, (process.stdout.rows || 34) - this.reservedRows - 2);
  }

  private maxScroll(bodyHeight = this.bodyHeight()): number {
    return Math.max(0, this.rendered.lines.length - bodyHeight);
  }

  render(width: number): string[] {
    const showToc = width >= MIN_TOC_TERMINAL_WIDTH;
    const tocWidth = showToc ? Math.min(MAX_TOC_WIDTH, Math.max(20, Math.floor(width * 0.2))) : 0;
    const gap = showToc ? 1 : 0;
    const bodyWidth = Math.max(30, width - tocWidth - gap);
    const contentWidth = bodyWidth - 4;

    const bodyHeight = this.bodyHeight();

    if (this.cachedWidth !== contentWidth) {
      this.rendered = renderMarkdown(this.markdown, contentWidth, this.Markdown, this.mdTheme);
      this.cachedWidth = contentWidth;
      this.scroll = Math.min(this.scroll, this.maxScroll(bodyHeight));
      this.selectedCodeBlock = Math.min(this.selectedCodeBlock, Math.max(0, this.rendered.codeBlocks.length - 1));
    }

    const maxScroll = this.maxScroll(bodyHeight);
    this.scroll = Math.max(0, Math.min(this.scroll, maxScroll));
    this.syncTocToScroll();
    this.syncCodeBlockToViewport();

    const top = this.theme.fg("borderAccent", `╭${"─".repeat(bodyWidth - 2)}╮`);
    const helpText = this.focus === "toc"
      ? "TOC · ↑↓/jk select · ←/→ collapse/expand · enter jump · tab body · q close"
      : "BODY · ↑↓/jk scroll · ←/→ code · c copy · tab toc · q close";
    const bottom = this.theme.fg(
      "borderAccent",
      `╰─ ${helpText} ${"─".repeat(Math.max(0, bodyWidth - visibleWidth(helpText) - 5))}╯`,
    );

    const bodyLines: string[] = [top];
    for (let i = 0; i < bodyHeight; i++) {
      const renderLine = this.scroll + i;
      const line = this.decorateCodeFence(this.rendered.lines[renderLine] ?? "", renderLine, contentWidth);
      bodyLines.push(
        this.theme.fg("border", "│ ") +
          padRight(truncateToWidth(line, contentWidth, "…"), contentWidth) +
          this.theme.fg("border", " │"),
      );
    }
    bodyLines.push(truncateToWidth(bottom, bodyWidth, ""));

    if (!showToc) return bodyLines.map((line) => padRight(truncateToWidth(line, width, ""), width));

    const tocLines = this.renderToc(tocWidth, bodyHeight + 2);
    return bodyLines.map((line, i) => {
      const body = padRight(truncateToWidth(line, bodyWidth, ""), bodyWidth);
      const toc = padRight(truncateToWidth(tocLines[i] ?? "", tocWidth, ""), tocWidth);
      return padRight(truncateToWidth(`${body} ${toc}`, width, ""), width);
    });
  }

  private decorateCodeFence(line: string, renderLine: number, width: number): string {
    const index = this.rendered.codeBlocks.findIndex((block) => block.renderLine === renderLine);
    if (index < 0 || index !== this.selectedCodeBlock) return line;

    const feedback = this.copyFeedback?.index === index ? this.copyFeedback.status : undefined;
    const label = feedback === "copied"
      ? this.theme.fg("success", "[copied]")
      : feedback === "failed"
        ? this.theme.fg("error", "[copy failed]")
        : this.theme.fg("accent", `[${this.theme.underline("c")}opy]`);
    const fence = line.replace(/\s+$/, "");
    const fenceWidth = Math.max(0, width - visibleWidth(label) - 1);
    return padRight(`${truncateToWidth(fence, fenceWidth, "…")} ${label}`, width);
  }

  private renderToc(width: number, height: number): string[] {
    const inner = width - 4;
    const lines: string[] = [this.theme.fg("borderAccent", `╭─ TOC ${"─".repeat(Math.max(0, width - 8))}╮`)];
    const tocHeadings = this.getTocHeadings();
    const visibleItems = Math.max(1, height - 2);
    const start = Math.max(0, Math.min(this.selectedHeading - Math.floor(visibleItems / 2), tocHeadings.length - visibleItems));

    for (let i = 0; i < visibleItems; i++) {
      const idx = start + i;
      const heading = tocHeadings[idx];
      let text = "";
      if (heading) {
        const selected = idx === this.selectedHeading;
        const marker = selected ? "› " : "  ";
        const singleH1 = heading === this.getSingleH1Heading();
        const control = !singleH1 && heading.level < 3 && this.hasChildren(heading)
          ? (this.getExpandedDepth(heading) > heading.level ? "▾ " : "▸ ")
          : "  ";
        const tocNumber = this.getTocNumber(heading);
        const number = singleH1 ? "" : tocNumber ? `${tocNumber} ` : `${idx + 1}. `;
        text = marker + control + number + heading.title;
        text = selected
          ? this.theme.fg("accent", truncateToWidth(text, inner, "…"))
          : this.theme.fg("muted", truncateToWidth(text, inner, "…"));
      }
      lines.push(this.theme.fg("border", "│ ") + padRight(text, inner) + this.theme.fg("border", " │"));
    }
    lines.push(this.theme.fg("borderAccent", `╰${"─".repeat(width - 2)}╯`));
    return lines;
  }

  handleInput(data: string): void {
    const bodyHeight = this.bodyHeight();
    const page = Math.max(1, Math.floor(bodyHeight / 2));
    const maxScroll = this.maxScroll(bodyHeight);

    const printable = decodePrintableKey(data) ?? (data.length === 1 ? data : undefined);

    if (printable && /^[0-9\.]$/.test(printable)) {
      this.numBuffer += printable;
      if (this.numTimer) clearTimeout(this.numTimer);
      const delayMs = this.numBuffer.length === 1 ? 250 : this.numBuffer.endsWith(".") ? 700 : 450;
      this.numTimer = setTimeout(() => {
        this.performNumberJump(this.numBuffer);
        this.numBuffer = "";
        this.numTimer = null;
        this.requestRender();
      }, delayMs);
      this.requestRender();
      return;
    }

    if (this.numTimer) {
      clearTimeout(this.numTimer);
      this.numTimer = null;
      this.numBuffer = "";
    }

    // Only allow focus-toggle to TOC when the terminal is wide enough to render a TOC.
    const showToc = (process.stdout.columns || 100) >= MIN_TOC_TERMINAL_WIDTH;

    if (matchesKey(data, Key.escape) || printable === "q" || printable === "Q") this.close();
    else if (matchesKey(data, Key.tab) && showToc) this.focus = this.focus === "body" ? "toc" : "body";
    else if (matchesKey(data, Key.enter) && this.focus === "toc") this.jumpToSelected();
    else if (matchesKey(data, Key.right)) this.focus === "toc" ? this.expandCurrent() : this.selectCodeBlock(1);
    else if (matchesKey(data, Key.left)) this.focus === "toc" ? this.collapseCurrent() : this.selectCodeBlock(-1);
    else if (printable === "c" && this.focus === "body") this.copySelectedCodeBlock();
    else if (matchesKey(data, Key.down) || printable === "j") this.focus === "toc" ? this.moveToc(1) : this.scrollBy(1);
    else if (matchesKey(data, Key.up) || printable === "k") this.focus === "toc" ? this.moveToc(-1) : this.scrollBy(-1);
    else if (matchesKey(data, Key.pageDown) || matchesKey(data, Key.space)) this.scrollBy(page);
    else if (matchesKey(data, Key.pageUp)) this.scrollBy(-page);
    else if (matchesKey(data, Key.home) || printable === "g") {
      this.scroll = 0;
      this.syncTocToScroll();
      this.syncCodeBlockToViewport();
    }
    else if (matchesKey(data, Key.end) || printable === "G") {
      this.scroll = maxScroll;
      this.syncTocToScroll();
      this.syncCodeBlockToViewport();
    }

    this.requestRender();
  }

  private performNumberJump(buf: string) {
    const normalized = buf.replace(/\.$/, "");
    if (!normalized) return;
    const toc = this.getTocHeadings();

    const exact = toc.findIndex((h) => this.getTocNumber(h) === normalized);
    if (exact >= 0) {
      this.selectedHeading = exact;
      this.jumpToSelected();
      return;
    }

    if (!normalized.includes(".")) {
      const idx = Number(normalized) - 1;
      if (idx >= 0 && idx < toc.length) {
        this.selectedHeading = idx;
        this.jumpToSelected();
      }
      return;
    }

    const prefix = toc.findIndex((h) => this.getTocNumber(h)?.startsWith(normalized));
    if (prefix >= 0) {
      this.selectedHeading = prefix;
      this.jumpToSelected();
    }
  }

  private scrollBy(n: number) {
    this.scroll = Math.max(0, Math.min(this.scroll + n, this.maxScroll()));
    this.syncTocToScroll();
    this.syncCodeBlockToViewport();
  }

  private selectCodeBlock(delta: number) {
    const blocks = this.rendered.codeBlocks;
    if (blocks.length === 0) return;

    this.selectedCodeBlock = (this.selectedCodeBlock + delta + blocks.length) % blocks.length;
    const line = blocks[this.selectedCodeBlock]!.renderLine;
    if (line < 0) return;

    const bodyHeight = this.bodyHeight();
    if (line < this.scroll) this.scroll = line;
    else if (line >= this.scroll + bodyHeight) this.scroll = line - bodyHeight + 1;
    this.scroll = Math.max(0, Math.min(this.scroll, this.maxScroll(bodyHeight)));
    this.syncTocToScroll();
  }

  private syncCodeBlockToViewport() {
    const blocks = this.rendered.codeBlocks;
    if (blocks.length === 0) return;

    const viewportEnd = this.scroll + this.bodyHeight() - 1;
    const selectedLine = blocks[this.selectedCodeBlock]?.renderLine ?? -1;
    if (selectedLine >= this.scroll && selectedLine <= viewportEnd) return;

    const visible = blocks
      .map((block, index) => ({ index, line: block.renderLine }))
      .filter(({ line }) => line >= this.scroll && line <= viewportEnd);
    if (visible.length === 0) return;

    const center = this.scroll + this.bodyHeight() / 2;
    visible.sort((a, b) => Math.abs(a.line - center) - Math.abs(b.line - center));
    this.selectedCodeBlock = visible[0]!.index;
  }

  private copySelectedCodeBlock() {
    const index = this.selectedCodeBlock;
    const block = this.rendered.codeBlocks[index];
    if (!block) return;

    void this.copyText(block.code).then(
      () => this.showCopyFeedback(index, "copied"),
      () => this.showCopyFeedback(index, "failed"),
    );
  }

  private showCopyFeedback(index: number, status: "copied" | "failed") {
    if (this.closed) return;
    if (this.copyTimer) clearTimeout(this.copyTimer);
    this.copyFeedback = { index, status };
    this.copyTimer = setTimeout(() => {
      this.copyFeedback = undefined;
      this.copyTimer = null;
      this.requestRender();
    }, 1200);
    this.requestRender();
  }

  private moveToc(n: number) {
    const tocHeadings = this.getTocHeadings();
    this.selectedHeading = Math.max(0, Math.min(this.selectedHeading + n, tocHeadings.length - 1));
    this.jumpToSelected(false);
  }

  private getTocHeadings(): Heading[] {
    const tocHeadings = this.rendered.headings.filter((h) => h.level <= 3);
    const rootLevel = this.getTocRootLevel();
    const singleH1 = this.getSingleH1Heading();
    const visible: Heading[] = [];

    if (singleH1) visible.push(singleH1);

    for (const heading of tocHeadings) {
      if (heading === singleH1) continue;
      if (heading.level === rootLevel) {
        visible.push(heading);
        continue;
      }
      if (heading.level < rootLevel) continue;
      const top = this.getTopKey(heading);
      const depth = this.expandedDepthByTop.get(top) ?? rootLevel;
      if (heading.level <= depth) visible.push(heading);
    }
    return visible;
  }

  private getSingleH1Heading(): Heading | undefined {
    const h1Headings = this.rendered.headings.filter((h) => h.level === 1);
    return h1Headings.length === 1 ? h1Headings[0] : undefined;
  }

  private getTocRootLevel(): number {
    const tocHeadings = this.rendered.headings.filter((h) => h.level <= 3);
    if (tocHeadings.length === 0) return 1;

    const singleH1 = this.getSingleH1Heading();
    if (singleH1) {
      const nonH1Levels = tocHeadings.filter((h) => h.level > 1).map((h) => h.level);
      if (nonH1Levels.length > 0) return Math.min(...nonH1Levels);
    }

    return Math.min(...tocHeadings.map((h) => h.level));
  }

  private getTopKey(heading: Heading): string {
    const rootLevel = this.getTocRootLevel();
    let top = heading;
    for (const candidate of this.rendered.headings) {
      if (candidate.sourceLine > heading.sourceLine) break;
      if (candidate.level === rootLevel) top = candidate;
    }
    return top.number ?? `${rootLevel}:${top.title}`;
  }

  private getTocNumber(heading: Heading): string | undefined {
    const singleH1 = this.getSingleH1Heading();
    if (!heading.number) return undefined;
    if (!singleH1) return heading.number;
    if (heading === singleH1) return undefined;

    const h1Prefix = singleH1.number ? `${singleH1.number}.` : undefined;
    if (h1Prefix && heading.number.startsWith(h1Prefix)) {
      return heading.number.slice(h1Prefix.length);
    }
    return heading.number;
  }

  private getExpandedDepth(heading: Heading): number {
    if (heading === this.getSingleH1Heading()) return this.getTocRootLevel();
    return this.expandedDepthByTop.get(this.getTopKey(heading)) ?? this.getTocRootLevel();
  }

  private hasChildren(heading: Heading): boolean {
    if (!heading.number) return false;
    const prefix = `${heading.number}.`;
    return this.rendered.headings.some((h) => h.level <= 3 && h.level > heading.level && h.number?.startsWith(prefix));
  }

  private expandCurrent() {
    const heading = this.getTocHeadings()[this.selectedHeading];
    if (!heading) return;
    const top = this.getTopKey(heading);
    const current = this.expandedDepthByTop.get(top) ?? this.getTocRootLevel();
    this.expandedDepthByTop.set(top, Math.min(3, Math.max(current + 1, heading.level + 1)));
    this.selectedHeading = this.findVisibleIndexForHeading(heading);
    this.jumpToSelected(false);
  }

  private collapseCurrent() {
    const heading = this.getTocHeadings()[this.selectedHeading];
    if (!heading) return;
    const top = this.getTopKey(heading);
    const current = this.expandedDepthByTop.get(top) ?? this.getTocRootLevel();
    const next = Math.max(this.getTocRootLevel(), current - 1);
    this.expandedDepthByTop.set(top, next);

    if (heading.level > next) {
      const topHeading = this.rendered.headings.find((h) => h.level === this.getTocRootLevel() && this.getTopKey(h) === top) ?? heading;
      this.selectedHeading = this.findVisibleIndexForHeading(topHeading);
    } else {
      this.selectedHeading = this.findVisibleIndexForHeading(heading);
    }
    this.jumpToSelected(false);
  }

  private findVisibleIndexForHeading(heading: Heading): number {
    const toc = this.getTocHeadings();
    const idx = toc.findIndex((h) => h === heading);
    return idx >= 0 ? idx : 0;
  }

  private syncTocToScroll() {
    if (this.focus === "toc") return;
    const toc = this.getTocHeadings();
    if (toc.length === 0) return;

    let active = 0;
    for (let i = 0; i < toc.length; i++) {
      if (toc[i]!.renderLine <= this.scroll) active = i;
      else break;
    }
    this.selectedHeading = active;
  }

  private jumpToSelected(returnFocusToBody = true) {
    const heading = this.getTocHeadings()[this.selectedHeading];
    if (heading) this.scroll = Math.max(0, Math.min(heading.renderLine, this.maxScroll()));
    if (returnFocusToBody) this.focus = "body";
  }

  invalidate(): void {
    this.cachedWidth = 0;
  }
}

export default function (pi: ExtensionAPI) {
  let latest = "";
  let pagerOpen = false;

  function restoreCursor() {
    if (process.stdout.isTTY) process.stdout.write("\x1b[?25h");
  }

  pi.registerFlag("pager", {
    description: "Open a Markdown file directly in the pager on startup",
    type: "string",
  });

  pi.registerFlag("no-pager-auto", {
    description: "Disable automatically opening the pager for responses taller than the current view",
    type: "boolean",
    default: false,
  });

  function hideFooter(ctx: any) {
    ctx.ui.setFooter(() => ({
      invalidate() {},
      render() { return []; },
    }));
  }

  // Helper that installs a pager footer renderer and returns a restore function.
  function installPagerFooter(ctx: any, renderFn: () => string[]) {
    ctx.ui.setFooter(() => ({
      invalidate() {},
      render() { return renderFn(); },
    }));
    return () => ctx.ui.setFooter(undefined);
  }

  async function openPager(ctx: any, markdown: string, options: { shutdownOnClose?: boolean } = {}) {
    if (!ctx.hasUI || pagerOpen) return;
    pagerOpen = true;
    let restoreFooter: (() => void) | undefined;
    try {
      restoreFooter = installPagerFooter(ctx, () => []);
      const reservedRows = 0;
      const mdTheme = getMarkdownTheme();
      await ctx.ui.custom((tui: any, theme: any, _keybindings: any, done: () => void) => {
        const pager = new MarkdownPager(markdown, theme, done, () => tui.requestRender(true), reservedRows, Markdown, mdTheme);
        setTimeout(() => tui.requestRender(true), 0);
        return pager;
      });
      if (options.shutdownOnClose) {
        restoreCursor();
        ctx.shutdown();
        setTimeout(() => {
          restoreCursor();
          process.exit(0);
        }, 0);
      }
    } finally {
      try {
        restoreFooter?.();
        ctx.ui.requestRender?.();
      } catch {}
      pagerOpen = false;
    }
  }

  function scheduleOpenPager(ctx: any, markdown: string) {
    setTimeout(() => {
      void openPager(ctx, markdown).catch((error) => {
        ctx.ui.notify(`Could not open pager: ${error}`, "error");
      });
    }, 0);
  }

  function isTallerThanCurrentView(markdown: string): boolean {
    const rows = process.stdout.rows || 34;
    const cols = process.stdout.columns || 100;
    const usableRows = Math.max(10, rows - 4);
    const approxBodyWidth = Math.max(40, Math.floor(cols * 0.78) - 4);
    let visualLines = 0;

    for (const line of normalizeMarkdownInput(markdown).split("\n")) {
      const width = Math.max(1, visibleWidth(line));
      visualLines += Math.max(1, Math.ceil(width / approxBodyWidth));
      if (visualLines > usableRows) return true;
    }

    return false;
  }

  pi.on("session_start", (_event, ctx) => {
    const pagerFile = pi.getFlag("pager") as string | undefined;
    if (!pagerFile) return;

    setTimeout(() => {
      void (async () => {
        try {
          hideFooter(ctx);
          const path = resolve(pagerFile);
          const markdown = readFileSync(path, "utf8");
          latest = markdown;
          await openPager(ctx, markdown, { shutdownOnClose: true });
        } catch (error) {
          ctx.ui.notify(`Could not open pager file: ${error}`, "error");
        }
      })();
    }, 0);
  });

  pi.on("message_end", (event, ctx) => {
    if (event.message.role !== "assistant") return;
    const text = extractText((event.message as any).content).trim();
    if (!text) return;

    latest = text;

    if (!pi.getFlag("no-pager-auto") && isTallerThanCurrentView(text)) {
      scheduleOpenPager(ctx, text);
    }
  });

  const pageCommand = {
    description: "Open latest assistant response, or a Markdown file: /page [path/to/file.md]",
    handler: async (args, ctx) => {
      if (!ctx.hasUI) return;
      const file = args.trim();

      if (file) {
        try {
          const markdown = readFileSync(resolve(file), "utf8");
          latest = markdown;
          await openPager(ctx, markdown);
        } catch (error) {
          ctx.ui.notify(`Could not open file: ${error}`, "error");
        }
        return;
      }

      if (!latest) {
        ctx.ui.notify("No assistant response captured yet", "warning");
        return;
      }

      await openPager(ctx, latest);
    },
  };

  pi.registerCommand("pager", pageCommand);
  pi.registerCommand("page", {
    ...pageCommand,
    description: "Alias for /pager",
  });
}
