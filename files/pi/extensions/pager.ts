import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { getMarkdownTheme } from "@earendil-works/pi-coding-agent";
import { Key, Markdown, matchesKey, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

type ContentBlock = { type?: string; text?: string };
type Heading = {
  level: number;
  title: string;
  sourceLine: number;
  renderLine: number;
  number?: string;
  explicitNumber?: string;
};
type Rendered = { lines: string[]; headings: Heading[] };

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
  const lines = text.split("\n");
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

function renderMarkdown(markdown: string, width: number): Rendered {
  const source = markdown.trimEnd().split("\n");
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
  const mdTheme = getMarkdownTheme();

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

  return { lines, headings };
}

class MarkdownPager {
  private scroll = 0;
  private selectedHeading = 0;
  private focus: "body" | "toc" = "body";
  private cachedWidth = 0;
  private rendered: Rendered = { lines: [], headings: [] };
  private expandedDepthByTop = new Map<string, number>();
  private numBuffer = "";
  private numTimer: NodeJS.Timeout | null = null;

  constructor(
    private markdown: string,
    private theme: any,
    private done: () => void,
    private requestRender: () => void,
  ) {}

  render(width: number): string[] {
    const showToc = width >= MIN_TOC_TERMINAL_WIDTH;
    const tocWidth = showToc ? Math.min(MAX_TOC_WIDTH, Math.max(20, Math.floor(width * 0.2))) : 0;
    const gap = showToc ? 1 : 0;
    const bodyWidth = Math.max(30, width - tocWidth - gap);
    const contentWidth = bodyWidth - 4;

    // One top border + one bottom help border. Leave a small amount for Pi's footer/editor area.
    const viewportHeight = Math.max(10, (process.stdout.rows || 34) - 2);

    if (this.cachedWidth !== contentWidth) {
      this.rendered = renderMarkdown(this.markdown, contentWidth);
      this.cachedWidth = contentWidth;
      this.scroll = Math.min(this.scroll, Math.max(0, this.rendered.lines.length - viewportHeight));
    }

    const maxScroll = Math.max(0, this.rendered.lines.length - viewportHeight);
    this.scroll = Math.max(0, Math.min(this.scroll, maxScroll));
    this.syncTocToScroll();

    const top = this.theme.fg("borderAccent", `╭${"─".repeat(bodyWidth - 2)}╮`);
    const helpText = `${this.focus === "toc" ? "TOC" : "BODY"} · ↑↓/jk scroll · ←/→ collapse/expand · tab toc · enter jump · q close`;
    const bottom = this.theme.fg(
      "borderAccent",
      `╰─ ${helpText} ${"─".repeat(Math.max(0, bodyWidth - visibleWidth(helpText) - 5))}╯`,
    );

    const bodyLines: string[] = [top];
    for (let i = 0; i < viewportHeight; i++) {
      const line = this.rendered.lines[this.scroll + i] ?? "";
      bodyLines.push(
        this.theme.fg("border", "│ ") +
          padRight(truncateToWidth(line, contentWidth, "…"), contentWidth) +
          this.theme.fg("border", " │"),
      );
    }
    bodyLines.push(truncateToWidth(bottom, bodyWidth, ""));

    if (!showToc) return bodyLines.map((l) => truncateToWidth(l, width, ""));

    const tocLines = this.renderToc(tocWidth, viewportHeight + 2);
    return bodyLines.map((line, i) => truncateToWidth(line, bodyWidth, "") + " " + (tocLines[i] ?? " ".repeat(tocWidth)));
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
        const control = heading.level < 3 && this.hasChildren(heading)
          ? (this.getExpandedDepth(heading) > heading.level ? "▾ " : "▸ ")
          : "  ";
        const number = heading.number ? `${heading.number} ` : `${idx + 1}. `;
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
    const page = Math.max(5, Math.min((process.stdout.rows || 34) - 10, 30));
    const maxScroll = Math.max(0, this.rendered.lines.length - page);

    if (/^[0-9\.]$/.test(data)) {
      this.numBuffer += data;
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

    if (matchesKey(data, Key.escape) || data === "q" || data === "Q") this.done();
    else if (matchesKey(data, Key.tab)) this.focus = this.focus === "body" ? "toc" : "body";
    else if (matchesKey(data, Key.enter) && this.focus === "toc") this.jumpToSelected();
    else if (matchesKey(data, Key.right) && this.focus === "toc") this.expandCurrent();
    else if (matchesKey(data, Key.left) && this.focus === "toc") this.collapseCurrent();
    else if (matchesKey(data, Key.down) || data === "j") this.focus === "toc" ? this.moveToc(1) : this.scrollBy(1);
    else if (matchesKey(data, Key.up) || data === "k") this.focus === "toc" ? this.moveToc(-1) : this.scrollBy(-1);
    else if (matchesKey(data, Key.pageDown) || data === " ") this.scrollBy(page);
    else if (matchesKey(data, Key.pageUp)) this.scrollBy(-page);
    else if (matchesKey(data, Key.home) || data === "g") {
      this.scroll = 0;
      this.syncTocToScroll();
    }
    else if (matchesKey(data, Key.end) || data === "G") {
      this.scroll = maxScroll;
      this.syncTocToScroll();
    }

    this.requestRender();
  }

  private performNumberJump(buf: string) {
    const normalized = buf.replace(/\.$/, "");
    if (!normalized) return;
    const toc = this.getTocHeadings();

    const exact = toc.findIndex((h) => h.number === normalized);
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

    const prefix = toc.findIndex((h) => h.number?.startsWith(normalized));
    if (prefix >= 0) {
      this.selectedHeading = prefix;
      this.jumpToSelected();
    }
  }

  private scrollBy(n: number) {
    this.scroll = Math.max(0, Math.min(this.scroll + n, Math.max(0, this.rendered.lines.length - 1)));
    this.syncTocToScroll();
  }

  private moveToc(n: number) {
    const tocHeadings = this.getTocHeadings();
    this.selectedHeading = Math.max(0, Math.min(this.selectedHeading + n, tocHeadings.length - 1));
    this.jumpToSelected(false);
  }

  private getTocHeadings(): Heading[] {
    const visible: Heading[] = [];
    for (const heading of this.rendered.headings) {
      if (heading.level > 3) continue;
      if (heading.level === 1) {
        visible.push(heading);
        continue;
      }
      const top = this.getTopKey(heading);
      const depth = this.expandedDepthByTop.get(top) ?? 1;
      if (heading.level <= depth) visible.push(heading);
    }
    return visible;
  }

  private getTopKey(heading: Heading): string {
    return heading.number?.split(".")[0] ?? "1";
  }

  private getExpandedDepth(heading: Heading): number {
    return this.expandedDepthByTop.get(this.getTopKey(heading)) ?? 1;
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
    const current = this.expandedDepthByTop.get(top) ?? 1;
    this.expandedDepthByTop.set(top, Math.min(3, Math.max(current + 1, heading.level + 1)));
    this.selectedHeading = this.findVisibleIndexForHeading(heading);
    this.jumpToSelected(false);
  }

  private collapseCurrent() {
    const heading = this.getTocHeadings()[this.selectedHeading];
    if (!heading) return;
    const top = this.getTopKey(heading);
    const current = this.expandedDepthByTop.get(top) ?? 1;
    const next = Math.max(1, current - 1);
    this.expandedDepthByTop.set(top, next);

    if (heading.level > next) {
      const topHeading = this.rendered.headings.find((h) => h.level === 1 && this.getTopKey(h) === top) ?? heading;
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
    if (heading) this.scroll = heading.renderLine;
    if (returnFocusToBody) this.focus = "body";
  }

  invalidate(): void {
    this.cachedWidth = 0;
  }
}

export default function (pi: ExtensionAPI) {
  let latest = "";
  let pagerOpen = false;

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

  async function openPager(ctx: any, markdown: string, options: { shutdownOnClose?: boolean } = {}) {
    if (!ctx.hasUI || pagerOpen) return;
    if (options.shutdownOnClose) hideFooter(ctx);
    pagerOpen = true;
    try {
      await ctx.ui.custom((tui: any, theme: any, _keybindings: any, done: () => void) => {
        return new MarkdownPager(markdown, theme, done, () => tui.requestRender());
      });
      if (options.shutdownOnClose) ctx.shutdown();
    } finally {
      pagerOpen = false;
    }
  }

  function isTallerThanCurrentView(markdown: string): boolean {
    const rows = process.stdout.rows || 34;
    const cols = process.stdout.columns || 100;
    const usableRows = Math.max(10, rows - 4);
    const approxBodyWidth = Math.max(40, Math.floor(cols * 0.78) - 4);
    let visualLines = 0;

    for (const line of markdown.split("\n")) {
      const width = Math.max(1, visibleWidth(line));
      visualLines += Math.max(1, Math.ceil(width / approxBodyWidth));
      if (visualLines > usableRows) return true;
    }

    return false;
  }

  pi.on("session_start", async (_event, ctx) => {
    const pagerFile = pi.getFlag("pager") as string | undefined;
    if (!pagerFile) return;

    try {
      hideFooter(ctx);
      const path = resolve(pagerFile);
      const markdown = readFileSync(path, "utf8");
      latest = markdown;
      await openPager(ctx, markdown, { shutdownOnClose: true });
    } catch (error) {
      ctx.ui.notify(`Could not open pager file: ${error}`, "error");
    }
  });

  pi.on("message_end", async (event, ctx) => {
    if (event.message.role !== "assistant") return;
    const text = extractText((event.message as any).content).trim();
    if (!text) return;

    latest = text;

    if (!pi.getFlag("no-pager-auto") && isTallerThanCurrentView(text)) {
      await openPager(ctx, text);
    }
  });

  pi.registerCommand("page", {
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
  });
}
