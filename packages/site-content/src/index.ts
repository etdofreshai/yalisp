export interface Feature {
  readonly index: string;
  readonly title: string;
  readonly description: string;
  readonly token: string;
}

export interface CodeLine {
  readonly number: number;
  readonly html: string;
}

export const features: readonly Feature[] = [
  {
    index: "01",
    title: "Small core, clear ideas",
    description:
      "A compact language that keeps the semantics close enough to hold in your head.",
    token: "(core)"
  },
  {
    index: "02",
    title: "Made to be explored",
    description:
      "Read it, change it, and follow each expression from source to result.",
    token: "(hack)"
  },
  {
    index: "03",
    title: "WebAssembly at the seed",
    description:
      "A checked-in WAT interpreter that runs the first Lisp-written bootstrap in browsers.",
    token: "(ship)"
  }
] as const;

export const codeLines: readonly CodeLine[] = [
  { number: 1, html: '<span class="syntax-muted">;; a tiny taste of YALisp</span>' },
  { number: 2, html: '<span class="syntax-paren">(</span><span class="syntax-key">define</span> factorial' },
  { number: 3, html: '  <span class="syntax-paren">(</span><span class="syntax-key">lambda</span> <span class="syntax-paren">(</span>n<span class="syntax-paren">)</span>' },
  { number: 4, html: '    <span class="syntax-paren">(</span><span class="syntax-key">if</span> <span class="syntax-paren">(</span>&lt;= n <span class="syntax-number">1</span><span class="syntax-paren">)</span>' },
  { number: 5, html: '      <span class="syntax-number">1</span>' },
  { number: 6, html: '      <span class="syntax-paren">(</span>* n <span class="syntax-paren">(</span>factorial <span class="syntax-paren">(</span>- n <span class="syntax-number">1</span><span class="syntax-paren">)</span><span class="syntax-paren">)</span><span class="syntax-paren">)</span><span class="syntax-paren">)</span><span class="syntax-paren">)</span><span class="syntax-paren">)</span>' },
  { number: 7, html: "" },
  { number: 8, html: '<span class="syntax-paren">(</span>factorial <span class="syntax-number">6</span><span class="syntax-paren">)</span> <span class="syntax-muted">; =&gt; 720</span>' }
] as const;

export const principles = ["Readable", "Hackable", "Portable"] as const;
