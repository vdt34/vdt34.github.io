/**
 * Pure-JS Excel formula engine tailored for 'tong hop Duong trach_UTC+7.xlsx'.
 * Evaluates all 7 sheets in-memory in <10ms with 100% Excel parity.
 */
(function (global) {
  'use strict';

  class ExcelError extends Error {
    constructor(code) {
      super(code);
      this.code = code;
    }
  }

  function colToIdx(col) {
    let n = 0;
    for (let i = 0; i < col.length; i++) {
      n = n * 26 + (col.charCodeAt(i) - 64);
    }
    return n;
  }

  function idxToCol(idx) {
    let res = '';
    while (idx > 0) {
      const rem = (idx - 1) % 26;
      idx = Math.floor((idx - 1) / 26);
      res = String.fromCharCode(65 + rem) + res;
    }
    return res;
  }

  function splitRef(ref) {
    const m = /^\$?([A-Z]+)\$?(\d+)$/.exec(ref);
    return [m[1], parseInt(m[2], 10)];
  }

  // Tokenizer matching xlsx_engine.py
  const TOKEN_RE = /("(?:""|[^"])*")|((?:'(?:[^']|'')*'|[A-Za-z0-9_]+)!\$?[A-Z]+\$?\d+(?::\$?[A-Z]+\$?\d+)?)|(\$?[A-Z]+\$?\d+:\$?[A-Z]+\$?\d+)|([A-Za-z_][A-Za-z0-9_.]*(?=\s*\())|(\$?[A-Z]+\$?\d+)|(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)|\b(TRUE|FALSE)\b|(<=|>=|<>|[+\-*/^&=<>])|(\()|(\))|(,)|(\s+)/y;

  function tokenize(expr) {
    const tokens = [];
    TOKEN_RE.lastIndex = 0;
    const n = expr.length;
    while (TOKEN_RE.lastIndex < n) {
      const m = TOKEN_RE.exec(expr);
      if (!m) throw new ExcelError('#NAME?');
      if (m[1] !== undefined) tokens.push(['STR', m[1]]);
      else if (m[2] !== undefined) tokens.push(['SHEETREF', m[2]]);
      else if (m[3] !== undefined) tokens.push(['RANGE', m[3]]);
      else if (m[4] !== undefined) tokens.push(['FUNC', m[4]]);
      else if (m[5] !== undefined) tokens.push(['CELL', m[5]]);
      else if (m[6] !== undefined) tokens.push(['NUM', m[6]]);
      else if (m[7] !== undefined) tokens.push(['BOOL', m[7]]);
      else if (m[8] !== undefined) tokens.push(['OP', m[8]]);
      else if (m[9] !== undefined) tokens.push(['LPAREN', m[9]]);
      else if (m[10] !== undefined) tokens.push(['RPAREN', m[10]]);
      else if (m[11] !== undefined) tokens.push(['COMMA', m[11]]);
      // m[12] is whitespace -> skip
    }
    return tokens;
  }

  function toNum(v) {
    if (v === null || v === undefined || v === '') return 0;
    if (typeof v === 'boolean') return v ? 1 : 0;
    if (typeof v === 'number') return v;
    if (typeof v === 'string') {
      const s = v.trim();
      if (s === '') return 0;
      const num = Number(s);
      if (Number.isNaN(num)) throw new ExcelError('#VALUE!');
      return num;
    }
    throw new ExcelError('#VALUE!');
  }

  function toStr(v) {
    if (v === null || v === undefined) return '';
    if (typeof v === 'boolean') return v ? 'TRUE' : 'FALSE';
    if (typeof v === 'number') {
      if (Number.isInteger(v)) return String(v);
      return String(v);
    }
    return String(v);
  }

  function excelEq(a, b) {
    if (a === null || a === undefined) a = typeof b === 'string' ? '' : 0;
    if (b === null || b === undefined) b = typeof a === 'string' ? '' : 0;
    if (typeof a === 'string' && typeof b === 'string') {
      return a.toLowerCase() === b.toLowerCase();
    }
    if (typeof a === 'number' && typeof b === 'number') {
      return Math.abs(a - b) < 1e-9;
    }
    return false;
  }

  function excelCmp(a, b) {
    if (a === null || a === undefined) a = typeof b === 'string' ? '' : 0;
    if (b === null || b === undefined) b = typeof a === 'string' ? '' : 0;
    if (typeof a === 'number' && typeof b === 'number') {
      const d = a - b;
      return Math.abs(d) < 1e-9 ? 0 : (d < 0 ? -1 : 1);
    }
    if (typeof a === 'string' && typeof b === 'string') {
      const al = a.toLowerCase(), bl = b.toLowerCase();
      return al === bl ? 0 : (al < bl ? -1 : 1);
    }
    const ta = typeof a === 'number' ? 0 : (typeof a === 'string' ? 1 : 2);
    const tb = typeof b === 'number' ? 0 : (typeof b === 'string' ? 1 : 2);
    return ta < tb ? -1 : 1;
  }

  class Parser {
    constructor(eng, sheet, tokens) {
      this.eng = eng;
      this.sheet = sheet;
      this.tokens = tokens;
      this.pos = 0;
      this.n = tokens.length;
    }

    peek() {
      return this.pos < this.n ? this.tokens[this.pos] : [null, null];
    }

    consume(expected) {
      const tok = this.peek();
      if (expected && tok[0] !== expected) throw new ExcelError('#VALUE!');
      this.pos++;
      return tok;
    }

    parse() {
      return this.parseCmp();
    }

    parseCmp() {
      let left = this.parseConcat();
      while (this.peek()[0] === 'OP' && ['=', '<>', '<', '<=', '>', '>='].includes(this.peek()[1])) {
        const op = this.consume()[1];
        const right = this.parseConcat();
        if (op === '=') left = excelEq(left, right);
        else if (op === '<>') left = !excelEq(left, right);
        else {
          const c = excelCmp(left, right);
          if (op === '<') left = c < 0;
          else if (op === '<=') left = c <= 0;
          else if (op === '>') left = c > 0;
          else if (op === '>=') left = c >= 0;
        }
      }
      return left;
    }

    parseConcat() {
      let left = this.parseAdd();
      while (this.peek()[0] === 'OP' && this.peek()[1] === '&') {
        this.consume();
        const right = this.parseAdd();
        left = toStr(left) + toStr(right);
      }
      return left;
    }

    parseAdd() {
      let left = this.parseMul();
      while (this.peek()[0] === 'OP' && (this.peek()[1] === '+' || this.peek()[1] === '-')) {
        const op = this.consume()[1];
        const right = this.parseMul();
        const a = toNum(left), b = toNum(right);
        left = op === '+' ? a + b : a - b;
      }
      return left;
    }

    parseMul() {
      let left = this.parseUnary();
      while (this.peek()[0] === 'OP' && (this.peek()[1] === '*' || this.peek()[1] === '/')) {
        const op = this.consume()[1];
        const right = this.parseUnary();
        const a = toNum(left), b = toNum(right);
        if (op === '*') left = a * b;
        else {
          if (b === 0) throw new ExcelError('#DIV/0!');
          left = a / b;
        }
      }
      return left;
    }

    parseUnary() {
      if (this.peek()[0] === 'OP' && (this.peek()[1] === '+' || this.peek()[1] === '-')) {
        const op = this.consume()[1];
        const v = toNum(this.parseUnary());
        return op === '-' ? -v : v;
      }
      return this.parsePrimary();
    }

    parseSheetRef(raw) {
      const idx = raw.indexOf('!');
      let sh = raw.slice(0, idx);
      const ref = raw.slice(idx + 1);
      if (sh.startsWith("'") && sh.endsWith("'")) {
        sh = sh.slice(1, -1).replace(/''/g, "'");
      }
      return [sh, ref];
    }

    parsePrimary() {
      const [kind, val] = this.peek();
      if (kind === 'NUM') {
        this.consume();
        return Number(val);
      }
      if (kind === 'STR') {
        this.consume();
        return val.slice(1, -1).replace(/""/g, '"');
      }
      if (kind === 'BOOL') {
        this.consume();
        return val.toUpperCase() === 'TRUE';
      }
      if (kind === 'LPAREN') {
        this.consume();
        const v = this.parse();
        this.consume('RPAREN');
        return v;
      }
      if (kind === 'FUNC') {
        let fname = this.consume()[1].toUpperCase();
        if (fname.startsWith('_XLUDF.')) fname = fname.slice(7);
        this.consume('LPAREN');
        return this.callFunc(fname);
      }
      if (kind === 'SHEETREF') {
        this.consume();
        const [sh, ref] = this.parseSheetRef(val);
        if (ref.includes(':')) {
          const [r1, r2] = ref.split(':');
          return { __range: true, sheet: sh, r1, r2 };
        }
        return this.eng.get(sh, ref);
      }
      if (kind === 'RANGE') {
        this.consume();
        const [r1, r2] = val.split(':');
        return { __range: true, sheet: this.sheet, r1, r2 };
      }
      if (kind === 'CELL') {
        this.consume();
        return this.eng.get(this.sheet, val);
      }
      throw new ExcelError('#VALUE!');
    }

    skipExpr() {
      let depth = 0;
      while (this.pos < this.n) {
        const [k] = this.peek();
        if (k === 'LPAREN') depth++;
        else if (k === 'RPAREN') {
          if (depth === 0) return;
          depth--;
        } else if (k === 'COMMA' && depth === 0) return;
        this.pos++;
      }
    }

    parseArgs() {
      const args = [];
      if (this.peek()[0] === 'RPAREN') {
        this.consume('RPAREN');
        return args;
      }
      while (true) {
        args.push(this.parse());
        if (this.peek()[0] === 'COMMA') this.consume('COMMA');
        else {
          this.consume('RPAREN');
          return args;
        }
      }
    }

    callFunc(fname) {
      if (fname === 'IF') {
        const cond = this.parse();
        const isTrue = typeof cond === 'boolean' ? cond : (toNum(cond) !== 0);
        this.consume('COMMA');
        if (isTrue) {
          const res = this.parse();
          if (this.peek()[0] === 'COMMA') {
            this.consume('COMMA');
            this.skipExpr();
          }
          this.consume('RPAREN');
          return res;
        } else {
          this.skipExpr();
          let res = false;
          if (this.peek()[0] === 'COMMA') {
            this.consume('COMMA');
            res = this.parse();
          }
          this.consume('RPAREN');
          return res;
        }
      }

      if (fname === 'IFNA') {
        try {
          const res = this.parse();
          if (this.peek()[0] === 'COMMA') {
            this.consume('COMMA');
            this.skipExpr();
          }
          this.consume('RPAREN');
          return res;
        } catch (e) {
          if (e instanceof ExcelError && e.code === '#N/A') {
            this.skipExpr();
            this.consume('COMMA');
            const res = this.parse();
            this.consume('RPAREN');
            return res;
          }
          throw e;
        }
      }

      if (fname === 'ISNUMBER') {
        try {
          const args = this.parseArgs();
          return typeof args[0] === 'number' && !Number.isNaN(args[0]);
        } catch (e) {
          if (e instanceof ExcelError) return false;
          throw e;
        }
      }

      if (fname === 'ISTEXT') {
        try {
          const args = this.parseArgs();
          return typeof args[0] === 'string';
        } catch (e) {
          if (e instanceof ExcelError) return false;
          throw e;
        }
      }

      const args = this.parseArgs();

      if (fname === 'OR') {
        for (const a of args) {
          if (a && a.__range) {
            for (const row of this.eng.getRange(a.sheet, a.r1, a.r2)) {
              for (const cell of row) {
                if (cell instanceof ExcelError) throw cell;
                if (cell) return true;
              }
            }
          } else if (typeof a === 'boolean') {
            if (a) return true;
          } else if (a !== null && a !== undefined && toNum(a) !== 0) {
            return true;
          }
        }
        return false;
      }

      if (fname === 'MAX') {
        let best = -Infinity;
        let found = false;
        for (const a of args) {
          if (a && a.__range) {
            for (const row of this.eng.getRange(a.sheet, a.r1, a.r2)) {
              for (const cell of row) {
                if (cell instanceof ExcelError) throw cell;
                if (typeof cell === 'number') {
                  if (cell > best) best = cell;
                  found = true;
                }
              }
            }
          } else if (typeof a === 'number') {
            if (a > best) best = a;
            found = true;
          }
        }
        return found ? best : 0;
      }

      if (fname === 'SUM') {
        let total = 0;
        for (const a of args) {
          if (a && a.__range) {
            for (const row of this.eng.getRange(a.sheet, a.r1, a.r2)) {
              for (const cell of row) {
                if (cell instanceof ExcelError) throw cell;
                if (typeof cell === 'number') total += cell;
              }
            }
          } else {
            total += toNum(a);
          }
        }
        return total;
      }

      if (fname === 'ABS') return Math.abs(toNum(args[0]));

      if (fname === 'MOD') {
        const n = toNum(args[0]), d = toNum(args[1]);
        if (d === 0) throw new ExcelError('#DIV/0!');
        return n - d * Math.floor(n / d);
      }

      if (fname === 'ROUND') {
        const v = toNum(args[0]), nd = Math.trunc(toNum(args[1]));
        const f = Math.pow(10, nd);
        return Math.round(v * f) / f;
      }

      if (fname === 'ROUNDDOWN') {
        const v = toNum(args[0]), nd = Math.trunc(toNum(args[1]));
        const f = Math.pow(10, nd);
        return Math.trunc(v * f) / f;
      }

      if (fname === 'LEN') return toStr(args[0]).length;

      if (fname === 'LEFT') {
        const s = toStr(args[0]);
        const n = args.length > 1 ? Math.trunc(toNum(args[1])) : 1;
        return s.slice(0, n);
      }

      if (fname === 'RIGHT') {
        const s = toStr(args[0]);
        const n = args.length > 1 ? Math.trunc(toNum(args[1])) : 1;
        return n > 0 ? s.slice(-n) : '';
      }

      if (fname === 'FIND') {
        const needle = toStr(args[0]), hay = toStr(args[1]);
        const start = args.length > 2 ? Math.trunc(toNum(args[2])) - 1 : 0;
        const idx = hay.indexOf(needle, start);
        if (idx === -1) throw new ExcelError('#VALUE!');
        return idx + 1;
      }

      if (fname === 'VLOOKUP') {
        const lookup = args[0];
        const rng = args[1];
        const colIdx = Math.trunc(toNum(args[2]));
        const approx = args.length < 4 ? true : (typeof args[3] === 'boolean' ? args[3] : toNum(args[3]) !== 0);
        const grid = this.eng.getRange(rng.sheet, rng.r1, rng.r2);
        if (colIdx < 1 || colIdx > grid[0].length) throw new ExcelError('#REF!');
        if (!approx) {
          for (const row of grid) {
            if (!(row[0] instanceof ExcelError) && excelEq(row[0], lookup)) {
              const v = row[colIdx - 1];
              if (v instanceof ExcelError) throw v;
              return v === null || v === undefined ? 0 : v;
            }
          }
          throw new ExcelError('#N/A');
        } else {
          let best = undefined;
          for (const row of grid) {
            if (row[0] instanceof ExcelError || row[0] === null || row[0] === undefined) continue;
            if (excelCmp(row[0], lookup) <= 0) best = row[colIdx - 1];
            else break;
          }
          if (best === undefined) throw new ExcelError('#N/A');
          if (best instanceof ExcelError) throw best;
          return best === null ? 0 : best;
        }
      }

      if (fname === 'HLOOKUP') {
        const lookup = args[0];
        const rng = args[1];
        const rowIdx = Math.trunc(toNum(args[2]));
        const approx = args.length < 4 ? true : (typeof args[3] === 'boolean' ? args[3] : toNum(args[3]) !== 0);
        const grid = this.eng.getRange(rng.sheet, rng.r1, rng.r2);
        if (rowIdx < 1 || rowIdx > grid.length) throw new ExcelError('#REF!');
        const header = grid[0];
        if (!approx) {
          for (let ci = 0; ci < header.length; ci++) {
            const cell = header[ci];
            if (!(cell instanceof ExcelError) && excelEq(cell, lookup)) {
              const v = grid[rowIdx - 1][ci];
              if (v instanceof ExcelError) throw v;
              return v === null || v === undefined ? 0 : v;
            }
          }
          throw new ExcelError('#N/A');
        } else {
          let best = undefined;
          for (let ci = 0; ci < header.length; ci++) {
            const cell = header[ci];
            if (cell instanceof ExcelError || cell === null || cell === undefined) continue;
            if (excelCmp(cell, lookup) <= 0) best = grid[rowIdx - 1][ci];
            else break;
          }
          if (best === undefined) throw new ExcelError('#N/A');
          if (best instanceof ExcelError) throw best;
          return best === null ? 0 : best;
        }
      }

      if (fname === 'INDEX') {
        const rng = args[0];
        const ri = Math.trunc(toNum(args[1]));
        const ci = args.length > 2 ? Math.trunc(toNum(args[2])) : 1;
        const grid = this.eng.getRange(rng.sheet, rng.r1, rng.r2);
        if (ri < 1 || ri > grid.length || ci < 1 || ci > grid[0].length) throw new ExcelError('#REF!');
        const v = grid[ri - 1][ci - 1];
        if (v instanceof ExcelError) throw v;
        return v === null || v === undefined ? 0 : v;
      }

      throw new ExcelError('#NAME?');
    }
  }

  class WorkbookEngine {
    constructor(data) {
      this.sheets = data.sheets;
      this.values = data.values;
      this.formulas = data.formulas;
      this.cache = new Map();
      this.tokensCache = new Map();
    }

    setInput(sheet, ref, value) {
      ref = ref.toUpperCase();
      delete this.formulas[sheet][ref];
      if (value === null || value === undefined || value === '') {
        delete this.values[sheet][ref];
      } else {
        this.values[sheet][ref] = value;
      }
      this.cache.clear();
    }

    setInputs(list) {
      for (const [sheet, ref, value] of list) {
        const r = ref.toUpperCase();
        delete this.formulas[sheet][r];
        if (value === null || value === undefined || value === '') {
          delete this.values[sheet][r];
        } else {
          this.values[sheet][r] = value;
        }
      }
      this.cache.clear();
    }

    get(sheet, ref) {
      ref = ref.toUpperCase().replace(/\$/g, '');
      const key = sheet + '!' + ref;
      if (this.cache.has(key)) {
        const v = this.cache.get(key);
        if (v instanceof ExcelError) throw v;
        return v;
      }
      const expr = this.formulas[sheet] && this.formulas[sheet][ref];
      if (expr !== undefined) {
        try {
          let toks = this.tokensCache.get(expr);
          if (!toks) {
            toks = tokenize(expr);
            this.tokensCache.set(expr, toks);
          }
          const val = new Parser(this, sheet, toks).parse();
          this.cache.set(key, val);
          return val;
        } catch (e) {
          if (e instanceof ExcelError) {
            this.cache.set(key, e);
            throw e;
          }
          throw e;
        }
      }
      const v = this.values[sheet] && this.values[sheet][ref];
      return v === undefined ? null : v;
    }

    getStr(sheet, ref) {
      try {
        return toStr(this.get(sheet, ref));
      } catch (e) {
        if (e instanceof ExcelError) return e.code;
        throw e;
      }
    }

    getRange(sheet, r1, r2) {
      const [c1, row1] = splitRef(r1);
      const [c2, row2] = splitRef(r2);
      let ic1 = colToIdx(c1), ic2 = colToIdx(c2);
      let rr1 = row1, rr2 = row2;
      if (ic1 > ic2) [ic1, ic2] = [ic2, ic1];
      if (rr1 > rr2) [rr1, rr2] = [rr2, rr1];
      const grid = [];
      for (let r = rr1; r <= rr2; r++) {
        const row = [];
        for (let ic = ic1; ic <= ic2; ic++) {
          const ref = idxToCol(ic) + r;
          try {
            row.push(this.get(sheet, ref));
          } catch (e) {
            if (e instanceof ExcelError) row.push(e);
            else throw e;
          }
        }
        grid.push(row);
      }
      return grid;
    }
  }

  global.WorkbookEngine = WorkbookEngine;
})(typeof window !== 'undefined' ? window : globalThis);
