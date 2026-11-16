#!/usr/bin/env node
// Compõe e sintetiza as músicas do Ativos Kart (assets/music/*.ogg).
//
// Tudo é gerado por código, como os efeitos sonoros do jogo (scripts/sfx.gd): cada
// instrumento é um sintetizador (onda quadrada, FM, Karplus-Strong, aditivo...) e cada
// faixa é uma partitura escrita aqui embaixo. As faixas são loops perfeitos: a
// música é tocada duas vezes seguidas e só a segunda passada é salva (assim o fim do
// loop já leva o reverb e as notas que soam do começo da próxima volta).
//
// Uso:  node tools/music/build_music.mjs [faixa ...] [--wav pasta]
//   sem faixas: gera todas. --wav também salva os WAV sem compressão na pasta.
// Precisa do ffmpeg (encoder Vorbis) no PATH.
//
// Estilo (pesquisado em trilhas de jogos de kart): base de fusion/funk com bateria e
// baixo na frente e frases curtas, harmonia com sétimas e nonas; a instrumentação muda
// com o cenário (tambor de aço na praia, escala frígia dominante e violão no deserto,
// guizos e glockenspiel na neve). Na volta final o jogo toca a faixa um tom acima e
// ~12% mais rápida (MusicPlayer.FINAL_LAP_PITCH). Todas as melodias são originais.

import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const SR = 44100;
const HERE = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(HERE, '..', '..');
const OUT_DIR = path.join(ROOT, 'assets', 'music');
const TAU = Math.PI * 2;

// --- Aleatório com semente (o mesmo resultado a cada execução) ----------------------

let _seed = 1;
function reseed(s) { _seed = s >>> 0 || 1; }
function rand() {
  _seed = (_seed + 0x6D2B79F5) | 0;
  let t = Math.imul(_seed ^ (_seed >>> 15), 1 | _seed);
  t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}
const noise = () => rand() * 2 - 1;

// --- Notas e acordes ----------------------------------------------------------------

const PC = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
function pitchClass(name) {
  let n = PC[name[0]];
  for (const ch of name.slice(1)) n += ch === '#' ? 1 : ch === 'b' ? -1 : 0;
  return (n + 12) % 12;
}
function midi(name) {
  const m = /^([A-G][#b]?)(-?\d)$/.exec(name);
  if (!m) throw new Error(`nota inválida: ${name}`);
  const base = PC[m[1][0]] + (m[1][1] === '#' ? 1 : m[1][1] === 'b' ? -1 : 0);
  return base + (parseInt(m[2], 10) + 1) * 12;
}
const mtof = (m) => 440 * Math.pow(2, (m - 69) / 12);

const QUALITIES = {
  '': [0, 4, 7], m: [0, 3, 7], 7: [0, 4, 7, 10], m7: [0, 3, 7, 10], maj7: [0, 4, 7, 11],
  maj9: [0, 4, 7, 11, 14], m9: [0, 3, 7, 10, 14], 9: [0, 4, 7, 10, 14], 6: [0, 4, 7, 9],
  m6: [0, 3, 7, 9], sus4: [0, 5, 7], '7sus4': [0, 5, 7, 10], sus2: [0, 2, 7], dim: [0, 3, 6],
  m7b5: [0, 3, 6, 10], aug: [0, 4, 8], '7b9': [0, 4, 7, 10, 13], add9: [0, 4, 7, 14],
  '69': [0, 4, 7, 9, 14], 13: [0, 4, 7, 10, 21],
};
function parseChord(sym) {
  const [main, bass] = sym.split('/');
  const m = /^([A-G][#b]?)(.*)$/.exec(main);
  if (!m || !(m[2] in QUALITIES)) throw new Error(`acorde inválido: ${sym}`);
  const root = pitchClass(m[1]);
  return { sym, root, iv: QUALITIES[m[2]], bass: bass ? pitchClass(bass) : root };
}

// Acordes por compasso: "Dmaj9 | Bm7 | A7sus4 A7" (dois no compasso = metade cada).
function chordBars(text) {
  return text.split('|').map((bar) => {
    const syms = bar.trim().split(/\s+/).filter(Boolean);
    const len = 16 / syms.length;
    return syms.map((s, i) => ({ ...parseChord(s), start: i * len, len }));
  });
}
function chordAt(bars, bar, step) {
  const list = bars[bar % bars.length];
  for (const c of list) if (step >= c.start && step < c.start + c.len) return c;
  return list[list.length - 1];
}

// Notas do acorde perto de `center` (vozes fechadas). `rootless` tira a fundamental
// (o baixo já toca), `top` limita a nota mais aguda.
function voicing(chord, center, { rootless = false, maxNotes = 4 } = {}) {
  let iv = chord.iv.map((x) => x % 12);
  if (rootless && iv.length >= 4) iv = iv.filter((x) => x !== 0);
  if (iv.length > maxNotes) iv = iv.filter((x) => x !== 7).slice(0, maxNotes);
  const notes = iv.map((x) => {
    const pc = (chord.root + x) % 12;
    let n = center - ((center - pc) % 12 + 12) % 12; // a nota pc mais perto abaixo de center
    if (center - n > 6) n += 12;
    return n;
  });
  return [...new Set(notes)].sort((a, b) => a - b);
}

// --- Filtros e osciladores ------------------------------------------------------------

class SVF {
  constructor() { this.ic1 = 0; this.ic2 = 0; this.lp = 0; this.bp = 0; this.hp = 0; }
  run(x, cutoff, q) {
    const g = Math.tan(Math.PI * Math.min(cutoff, SR * 0.45) / SR);
    const k = 1 / q;
    const a1 = 1 / (1 + g * (g + k));
    const a2 = g * a1;
    const a3 = g * a2;
    const v3 = x - this.ic2;
    const v1 = a1 * this.ic1 + a2 * v3;
    const v2 = this.ic2 + a2 * this.ic1 + a3 * v3;
    this.ic1 = 2 * v1 - this.ic1;
    this.ic2 = 2 * v2 - this.ic2;
    this.lp = v2; this.bp = v1; this.hp = x - k * v1 - v2;
    return v2;
  }
}
function blep(t, dt) {
  if (t < dt) { t /= dt; return t + t - t * t - 1; }
  if (t > 1 - dt) { t = (t - 1) / dt; return t * t + t + t + 1; }
  return 0;
}
// Envelope ADSR com release exponencial depois de `dur`.
function env(t, dur, a, d, s, r) {
  let e;
  if (t < a) e = t / a;
  else if (t < a + d) e = 1 - (1 - s) * ((t - a) / d);
  else e = s;
  if (t > dur) e *= Math.exp(-(t - dur) / r);
  return e;
}
function highpassInPlace(buf, cutoff) {
  const rc = 1 / (TAU * cutoff);
  const alpha = rc / (rc + 1 / SR);
  let px = 0, py = 0;
  for (let i = 0; i < buf.length; i++) {
    const y = alpha * (py + buf[i] - px);
    px = buf[i]; py = y; buf[i] = y;
  }
  return buf;
}

// --- Instrumentos melódicos -----------------------------------------------------------
// Cada um devolve um Float32Array mono com a nota (frequência f, duração dur em s,
// intensidade vel de 0 a 1).

// Onda quadrada (pulso) com vibrato: o "lead" de videogame.
function lead(f, dur, vel, o = {}) {
  const duty = o.duty ?? 0.5, rel = o.rel ?? 0.07, vibDepth = o.vib ?? 0.16;
  const cutoff = o.cutoff ?? 5200, detune = o.detune ?? 7;
  const n = Math.ceil((dur + rel * 5) * SR);
  const out = new Float32Array(n);
  const flt = new SVF();
  let p1 = 0, p2 = 0.3;
  const d2 = Math.pow(2, detune / 1200);
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const vt = t - 0.16;
    const vib = vt > 0 ? vibDepth * Math.min(1, vt / 0.3) * Math.sin(TAU * 5.6 * vt) : 0;
    const ff = f * Math.pow(2, vib / 12);
    const dt1 = ff / SR, dt2 = ff * d2 / SR;
    p1 += dt1; if (p1 >= 1) p1 -= 1;
    p2 += dt2; if (p2 >= 1) p2 -= 1;
    let v1 = (p1 < duty ? 1 : -1) + blep(p1, dt1) - blep((p1 + 1 - duty) % 1, dt1);
    let v2 = (p2 < duty ? 1 : -1) + blep(p2, dt2) - blep((p2 + 1 - duty) % 1, dt2);
    const e = env(t, dur, o.att ?? 0.006, o.dec ?? 0.22, o.sus ?? 0.7, rel);
    out[i] = flt.run((v1 + v2 * 0.6) * 0.5, cutoff, 0.7) * e * vel;
  }
  return out;
}

// Metais sintetizados: serras desafinadas, filtro que abre no ataque e "scoop".
function brass(f, dur, vel, o = {}) {
  const rel = o.rel ?? 0.09;
  const n = Math.ceil((dur + rel * 5) * SR);
  const out = new Float32Array(n);
  const flt = new SVF();
  const det = [-9, 0, 8].map((c) => Math.pow(2, c / 1200));
  const ph = [0, 0.33, 0.66];
  const bright = o.bright ?? 1;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const scoop = -0.35 * Math.exp(-t / 0.035);
    const vt = t - 0.25;
    const vib = vt > 0 ? 0.12 * Math.min(1, vt / 0.3) * Math.sin(TAU * 5.2 * vt) : 0;
    const ff = f * Math.pow(2, (scoop + vib) / 12);
    let s = 0;
    for (let k = 0; k < 3; k++) {
      const dt = ff * det[k] / SR;
      ph[k] += dt; if (ph[k] >= 1) ph[k] -= 1;
      s += 2 * ph[k] - 1 - blep(ph[k], dt);
    }
    const fe = Math.min(1, t / 0.03) * (0.45 + 0.55 * Math.exp(-t / 0.22));
    const cutoff = f * (1.2 + 7 * fe * bright * (0.6 + 0.4 * vel));
    const e = env(t, dur, 0.018, 0.2, 0.8, rel);
    out[i] = flt.run(s * 0.35, cutoff, 0.8) * e * vel;
  }
  return out;
}

// Piano elétrico (FM): mais forte = mais brilhante, com o "tine" do martelo.
function epiano(f, dur, vel, o = {}) {
  const rel = o.rel ?? 0.18;
  const n = Math.ceil((dur + rel * 5) * SR);
  const out = new Float32Array(n);
  const w = TAU * f / SR;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const I = (1.6 * vel + 0.35) * Math.exp(-t / 0.4) + 0.2;
    const car = Math.sin(w * i + I * Math.sin(w * i));
    const tine = Math.sin(w * 13.9 * i) * Math.exp(-t / 0.012) * 0.18 * vel;
    let a = Math.exp(-t / 1.9) * Math.min(1, t / 0.003);
    if (t > dur) a *= Math.exp(-(t - dur) / rel);
    out[i] = (car + tine) * a * vel * 0.6;
  }
  return out;
}

// Baixo (dedo/slap): serra filtrada com envelope + subgrave em seno.
function bass(f, dur, vel, o = {}) {
  const rel = o.rel ?? 0.035, bright = o.bright ?? 5, slap = o.slap ?? 0;
  const n = Math.ceil((dur + rel * 6) * SR);
  const out = new Float32Array(n);
  const flt = new SVF();
  let p = 0, ps = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const dt = f / SR;
    p += dt; if (p >= 1) p -= 1;
    ps += dt; if (ps >= 1) ps -= 1;
    const saw = 2 * p - 1 - blep(p, dt);
    const cutoff = f * (1.4 + bright * (0.5 + slap) * Math.exp(-t / (0.06 + slap * 0.03)));
    let s = flt.run(saw, cutoff, 0.9) * 0.8 + Math.sin(TAU * ps) * 0.32;
    if (slap > 0 && t < 0.004) s += noise() * slap * (1 - t / 0.004) * 0.6;
    const e = env(t, dur, 0.002, 0.3, 0.72, rel);
    out[i] = s * e * vel;
  }
  return out;
}

// Nota abafada do baixo (ghost note): só o estalo.
function deadNote(f, dur, vel) {
  const n = Math.ceil(0.05 * SR);
  const out = new Float32Array(n);
  const flt = new SVF();
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    out[i] = flt.run(noise() * 0.5 + Math.sin(TAU * f * t), f * 3, 1.2) * Math.exp(-t / 0.012) * vel;
  }
  return out;
}

// Corda dedilhada (Karplus-Strong): violão, guitarra, cavaquinho, pizzicato.
// t60: tempo para sumir; bright: 0 (abafado) a 1 (estalado); pick: posição da palheta.
function pluck(f, dur, vel, o = {}) {
  const t60 = o.t60 ?? 2.0, bright = o.bright ?? 0.5, pick = o.pick ?? 0.18;
  const rel = o.rel ?? 0.06;
  const tail = Math.min(t60, dur + rel * 6);
  const n = Math.ceil((tail + 0.02) * SR);
  const out = new Float32Array(n);
  const D = SR / f - 0.5;
  const g = Math.pow(10, -3 / (t60 * f));
  const s = 0.5 - bright * 0.45; // filtro do laço
  // Excitação: ruído suavizado com o pente da posição da palheta.
  const L = Math.max(2, Math.floor(D));
  const exc = new Float32Array(L);
  let lp = 0;
  const a = 0.15 + bright * 0.8;
  for (let i = 0; i < L; i++) { lp += a * (noise() - lp); exc[i] = lp; }
  const pk = Math.max(1, Math.floor(L * pick));
  for (let i = L - 1; i >= pk; i--) exc[i] -= exc[i - pk];
  for (let i = 0; i < n; i++) {
    let y = i < L ? exc[i] : 0;
    const r = i - D;
    if (r >= 1) {
      const i0 = Math.floor(r), fr = r - i0;
      const y0 = out[i0] * (1 - fr) + out[i0 + 1 < i ? i0 + 1 : i0] * fr;
      const y1 = out[i0 - 1] * (1 - fr) + out[i0] * fr;
      y += g * ((1 - s) * y0 + s * y1);
    }
    out[i] = y;
  }
  // Abafa depois da duração (mão em cima das cordas). A saturação leve segura o
  // estalo do ataque (senão ele vira o pico da música inteira).
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    let e = Math.min(1, t / 0.0015);
    if (t > dur) e *= Math.exp(-(t - dur) / rel);
    out[i] = Math.tanh(out[i] * 2.2) / 2.2 * e * vel * 1.9;
  }
  highpassInPlace(out, 60);
  if (o.trem) {
    for (let i = 0; i < n; i++) out[i] *= 1 - o.trem * (0.5 + 0.5 * Math.sin(TAU * 6.5 * i / SR));
  }
  return out;
}

// Sons de percussão afinada (tambor de aço, marimba, glockenspiel, vibrafone,
// celesta): soma de parciais [razão, volume, decaimento em s].
function mallet(partials, f, dur, vel, o = {}) {
  const ring = o.ring ?? 1, rel = o.rel ?? 0.12;
  const longest = Math.max(...partials.map((p) => p[2]));
  const n = Math.ceil(Math.min(dur + rel * 6, longest * 5 * ring + 0.05) * SR);
  const out = new Float32Array(n);
  const bend = o.bend ?? 0;
  for (const [ratio, amp, tau] of partials) {
    const fr = f * ratio;
    if (fr > SR * 0.45) continue;
    let ph = rand();
    for (let i = 0; i < n; i++) {
      const t = i / SR;
      const ff = fr * Math.pow(2, (bend * Math.exp(-t / 0.03)) / 12);
      ph += ff / SR;
      out[i] += Math.sin(TAU * ph) * amp * Math.exp(-t / (tau * ring));
    }
  }
  const trem = o.trem ?? 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    let e = Math.min(1, t / (o.att ?? 0.0015));
    if (t > dur) e *= Math.exp(-(t - dur) / rel);
    if (trem) e *= 1 - trem * (0.5 + 0.5 * Math.sin(TAU * 5.2 * t));
    out[i] *= e * vel;
  }
  if (o.click) for (let i = 0; i < Math.min(n, 120); i++) out[i] += noise() * o.click * vel * (1 - i / 120);
  return out;
}
const STEELPAN = [[1, 1, 0.75], [2, 0.75, 0.5], [3, 0.3, 0.3], [4, 0.14, 0.2], [2.76, 0.08, 0.12]];
const MARIMBA = [[1, 1, 0.5], [3.93, 0.35, 0.09], [9.2, 0.08, 0.03]];
const GLOCK = [[1, 1, 1.4], [2.76, 0.4, 0.45], [5.4, 0.18, 0.2], [8.93, 0.08, 0.1]];
const CELESTA = [[1, 1, 0.9], [2, 0.3, 0.5], [3, 0.12, 0.25], [4.1, 0.05, 0.12]];
const VIBES = [[1, 1, 2.2], [4, 0.22, 0.5], [10, 0.04, 0.15]];
const steelpan = (f, d, v, o = {}) => mallet(STEELPAN, f, d, v, { bend: 0.25, rel: 0.25, ...o });
const marimba = (f, d, v, o = {}) => mallet(MARIMBA, f, d, v, { click: 0.15, rel: 0.08, ...o });
const glock = (f, d, v, o = {}) => mallet(GLOCK, f, d, v, { click: 0.1, rel: 0.6, ...o });
const celesta = (f, d, v, o = {}) => mallet(CELESTA, f, d, v, { rel: 0.3, ...o });
const vibes = (f, d, v, o = {}) => mallet(VIBES, f, d, v, { trem: 0.3, rel: 0.4, ...o });

// Pad (cordas sintéticas): serras desafinadas, ataque e saída lentos.
function pad(f, dur, vel, o = {}) {
  const att = o.att ?? 0.3, rel = o.rel ?? 0.6, cutoff = o.cutoff ?? 1800;
  const n = Math.ceil((dur + rel * 4) * SR);
  const out = new Float32Array(n);
  const flt = new SVF();
  const det = [-14, -5, 5, 13].map((c) => Math.pow(2, c / 1200));
  const ph = det.map(() => rand());
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    let s = 0;
    for (let k = 0; k < 4; k++) {
      const dt = f * det[k] / SR;
      ph[k] += dt; if (ph[k] >= 1) ph[k] -= 1;
      s += 2 * ph[k] - 1 - blep(ph[k], dt);
    }
    const e = env(t, dur, att, 0.3, 0.9, rel);
    out[i] = flt.run(s * 0.25, cutoff * (1 + 0.15 * Math.sin(TAU * 0.4 * t)), 0.7) * e * vel;
  }
  return out;
}

// Assobio (faroeste) e flauta (neve): seno com sopro e vibrato.
function whistle(f, dur, vel, o = {}) {
  const rel = o.rel ?? 0.1, vibDepth = o.vib ?? 0.3, breath = o.breath ?? 0.12;
  const n = Math.ceil((dur + rel * 5) * SR);
  const out = new Float32Array(n);
  const bp = new SVF();
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const scoop = (o.scoop ?? -0.8) * Math.exp(-t / 0.05);
    const vt = t - (o.vibDelay ?? 0.12);
    const vib = vt > 0 ? vibDepth * Math.min(1, vt / 0.25) * Math.sin(TAU * (o.vibRate ?? 5.8) * vt) : 0;
    const ff = f * Math.pow(2, (scoop + vib) / 12);
    ph += ff / SR; if (ph >= 1) ph -= 1;
    const tone = Math.sin(TAU * ph) + 0.08 * Math.sin(2 * TAU * ph) + (o.tri ?? 0) * Math.sin(3 * TAU * ph) / 9;
    const air = bp.run(noise(), ff, 4) * breath;
    const e = env(t, dur, o.att ?? 0.03, 0.15, 0.85, rel);
    out[i] = (tone + air) * e * vel;
  }
  return out;
}

// Pulso fininho sem filtro (arpejos "chiptune").
function chip(f, dur, vel, o = {}) {
  const duty = o.duty ?? 0.25;
  const n = Math.ceil((dur + 0.03) * SR);
  const out = new Float32Array(n);
  let p = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const dt = f / SR;
    p += dt; if (p >= 1) p -= 1;
    const v = (p < duty ? 1 : -1) + blep(p, dt) - blep((p + 1 - duty) % 1, dt);
    out[i] = v * Math.exp(-t / (o.decay ?? 0.09)) * Math.min(1, (dur + 0.03 - t) / 0.01) * vel * 0.5;
  }
  return out;
}

// --- Bateria e percussão (cada função devolve uma batida) -----------------------------

function buf(sec) { return new Float32Array(Math.ceil(sec * SR)); }
function kick(vel) {
  const out = buf(0.35); let ph = 0;
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    ph += (54 + 120 * Math.exp(-t / 0.025)) / SR;
    let s = Math.sin(TAU * ph) * Math.exp(-t / 0.16);
    if (t < 0.002) s += noise() * 0.6;
    out[i] = Math.tanh(s * 1.8) * vel;
  }
  return highpassInPlace(highpassInPlace(out, 38), 38);
}
function snare(vel, o = {}) {
  const out = buf(0.3); const bp = new SVF(); const hp = new SVF();
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    const tone = (Math.sin(TAU * 185 * t) * 0.8 + Math.sin(TAU * 330 * t) * 0.3) * Math.exp(-t / 0.06);
    const n = noise();
    bp.run(n, 3200, 0.6); hp.run(n, 1500, 0.7);
    const rattle = (bp.bp * 0.7 + hp.hp * 0.5) * Math.exp(-t / (o.tail ?? 0.13));
    out[i] = (tone * 0.55 + rattle) * vel;
  }
  return out;
}
function rim(vel) {
  const out = buf(0.05);
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    out[i] = (Math.sin(TAU * 1750 * t) * Math.exp(-t / 0.008) + Math.sin(TAU * 520 * t) * Math.exp(-t / 0.014) * 0.6) * vel;
  }
  return out;
}
function hat(vel, open = false) {
  const out = buf(open ? 0.4 : 0.07); const hp = new SVF(); const lp = new SVF();
  const tau = open ? 0.18 : 0.022;
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    // Ruído + senos inarmônicos (o "metal" do prato).
    let m = 0;
    for (const fr of [3150, 4720, 5880, 7350, 8810]) m += Math.sin(TAU * fr * t + fr);
    hp.run(noise() * 0.7 + m * 0.1, 7000, 0.8);
    out[i] = lp.run(hp.hp, 13000, 0.7) * Math.exp(-t / tau) * vel * 1.3;
  }
  return out;
}
function crash(vel) {
  const out = buf(1.8); const hp = new SVF();
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    let m = 0;
    for (const fr of [2950, 4210, 5530, 6890, 8130]) m += Math.sin(TAU * fr * t + fr);
    hp.run(noise() * 0.8 + m * 0.08, 4500, 0.7);
    out[i] = hp.hp * Math.exp(-t / 0.55) * Math.min(1, t / 0.002) * vel;
  }
  return out;
}
function clap(vel) {
  const out = buf(0.25); const bp = new SVF();
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    let e = 0;
    for (const o of [0, 0.011, 0.022]) if (t >= o) e = Math.max(e, Math.exp(-(t - o) / 0.006));
    e = Math.max(e, t > 0.022 ? Math.exp(-(t - 0.022) / 0.09) * 0.6 : 0);
    bp.run(noise(), 1300, 1.2);
    out[i] = bp.bp * 1.6 * e * vel;
  }
  return out;
}
function conga(vel, freq = 210, slap = false) {
  const out = buf(0.3);
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    const f = freq * (1 + 0.18 * Math.exp(-t / 0.015));
    let s = Math.sin(TAU * f * t) * Math.exp(-t / (slap ? 0.06 : 0.16));
    if (t < 0.003) s += noise() * (slap ? 0.8 : 0.3);
    out[i] = s * vel;
  }
  return out;
}
function shaker(vel) {
  const out = buf(0.09); const hp = new SVF();
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    const e = Math.min(1, t / 0.012) * Math.exp(-Math.max(0, t - 0.012) / 0.03);
    hp.run(noise(), 5000, 0.7);
    out[i] = hp.hp * e * vel;
  }
  return out;
}
function woodblock(vel, freq = 1100) {
  const out = buf(0.06);
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    out[i] = (Math.sin(TAU * freq * t) + 0.4 * Math.sin(TAU * freq * 2.7 * t)) * Math.exp(-t / 0.018) * vel;
  }
  return out;
}
function cowbell(vel) {
  const out = buf(0.25); const bp = new SVF();
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    const s = Math.sign(Math.sin(TAU * 540 * t)) + Math.sign(Math.sin(TAU * 800 * t));
    bp.run(s, 900, 2);
    out[i] = bp.bp * Math.exp(-t / 0.07) * vel * 0.8;
  }
  return out;
}
function castanets(vel) {
  const out = buf(0.05); const bp = new SVF();
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    let e = 0;
    for (const o of [0, 0.009]) if (t >= o) e = Math.max(e, Math.exp(-(t - o) / 0.004));
    bp.run(noise(), 2600, 2.5);
    out[i] = bp.bp * e * vel * 1.3;
  }
  return out;
}
function tambourine(vel) {
  const out = buf(0.22); const hp = new SVF();
  const jingles = [6200, 7450, 8100, 9300, 10500].map((f) => [f, rand() * 0.008]);
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    let m = 0;
    for (const [f, d] of jingles) if (t >= d) m += Math.sin(TAU * f * (t - d)) * Math.exp(-(t - d) / 0.05);
    hp.run(noise(), 6000, 0.7);
    out[i] = (m * 0.18 + hp.hp * 0.5 * Math.exp(-t / 0.06)) * vel;
  }
  return out;
}
// Guizos de trenó: vários sininhos batendo quase juntos.
function sleighbells(vel) {
  const out = buf(0.3); const hp = new SVF();
  const hits = [];
  for (let k = 0; k < 7; k++) hits.push([rand() * 0.04, 5200 + rand() * 5200, 0.5 + rand() * 0.5]);
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    let m = 0;
    for (const [d, f, a] of hits) if (t >= d) {
      const u = t - d;
      m += (Math.sin(TAU * f * u) + 0.5 * Math.sin(TAU * f * 1.48 * u)) * a * Math.exp(-u / 0.035);
    }
    hp.run(noise(), 7000, 0.7);
    out[i] = (m * 0.12 + hp.hp * 0.25 * Math.exp(-t / 0.04)) * vel;
  }
  return out;
}
// Darbuka (deserto): "dum" grave e "tek" estalado.
function dum(vel) { return conga(vel, 105, false); }
function tek(vel) {
  const out = buf(0.06); const bp = new SVF();
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    bp.run(noise(), 3800, 1.5);
    out[i] = (bp.bp * 1.2 + Math.sin(TAU * 620 * t) * 0.5) * Math.exp(-t / 0.012) * vel;
  }
  return out;
}
function tom(vel, freq = 120) {
  const out = buf(0.45);
  for (let i = 0; i < out.length; i++) {
    const t = i / SR;
    const f = freq * (1 + 0.3 * Math.exp(-t / 0.04));
    out[i] = (Math.sin(TAU * f * t) + (t < 0.004 ? noise() * 0.4 : 0)) * Math.exp(-t / 0.22) * vel;
  }
  return out;
}

// --- Partitura --------------------------------------------------------------------------

// Um canal do mixer: volume, posição no estéreo (-1 esquerda, 1 direita) e quanto vai
// para o reverb e para o eco.
const ch = (gain, pan = 0, rev = 0.15, dly = 0) => ({ gain, pan, rev, dly });

class Song {
  constructor({ name, bpm, bars, swing = 0, seed = 7, reverb = {}, delay = {} }) {
    Object.assign(this, { name, bpm, bars, swing, seed, reverbOpt: reverb, delayOpt: delay });
    // A semicolcheia tem um número inteiro de amostras: o loop fica com um tamanho
    // múltiplo de 128 amostras e o encoder Vorbis não precisa completar o fim com
    // silêncio (o que daria um buraquinho a cada volta do loop).
    this.six = Math.round(SR * 60 / bpm / 4) / SR;
    this.length = bars * 16 * this.six;
    this.events = [];
    reseed(seed);
  }
  time(bar, step) {
    let s = step;
    const whole = Math.floor(step);
    if (this.swing && whole % 2 === 1 && step === whole) s += this.swing;
    return (bar * 16 + s) * this.six;
  }
  // Nota com um pouco de "mão humana" (tempo e força variam de leve).
  note(inst, chan, bar, step, len, m, vel, opts = {}) {
    const human = opts.tight ? 0 : (rand() - 0.5) * 0.006;
    this.events.push({
      inst, chan, opts,
      t: this.time(bar, step) + human,
      dur: len * this.six * (opts.gate ?? 0.92),
      f: mtof(m), vel: vel * (1 + (rand() - 0.5) * 0.1),
    });
  }
  hit(fn, chan, bar, step, vel, arg) {
    this.events.push({ drum: fn, chan, arg, t: this.time(bar, step) + (rand() - 0.5) * 0.003, vel: vel * (1 + (rand() - 0.5) * 0.12) });
  }

  // Melodia: "E5 4 D5 2 r 2 | ..." (nota e duração em semicolcheias; r = pausa).
  // Cada compasso tem que somar 16. `transpose` em semitons.
  melody(inst, chan, startBar, text, o = {}) {
    const bars = text.split('|');
    bars.forEach((barText, bi) => {
      const tk = barText.trim().split(/\s+/).filter(Boolean);
      if (tk.length % 2) throw new Error(`${this.name}: melodia incompleta no compasso ${startBar + bi}: ${barText}`);
      let step = 0;
      for (let i = 0; i < tk.length; i += 2) {
        const len = parseFloat(tk[i + 1]);
        if (tk[i] !== 'r') {
          const m = midi(tk[i]) + (o.transpose ?? 0);
          const vel = (o.vel ?? 0.8) * (step % 4 === 0 ? 1 : 0.9);
          if (o.roll && len >= o.roll) {
            // Rufo (tambor de aço segurando a nota): repete a nota em fusas.
            for (let s = 0; s < len; s += 0.5) this.note(inst, chan, startBar + bi, step + s, 0.5, m, vel * (s === 0 ? 1 : 0.55 + rand() * 0.15), { ...o.opts, gate: 1 });
          } else {
            this.note(inst, chan, startBar + bi, step, len, m, vel, { ...o.opts, gate: o.gate ?? 0.92 });
          }
        }
        step += len;
      }
      if (Math.abs(step - 16) > 1e-6) throw new Error(`${this.name}: compasso ${startBar + bi} soma ${step}: ${barText}`);
    });
  }

  // Linha de baixo sobre os acordes: 16 símbolos por compasso, separados por espaço.
  // R fundamental (ou o baixo do acorde com barra), 3, 5, 7 (sétima do acorde),
  // 8 oitava, 6, 9, 4, A/a aproximação cromática (de baixo/de cima) para o próximo
  // acorde, x nota abafada, - segura a anterior, . pausa.
  bassline(inst, chan, chords, startBar, nBars, patterns, o = {}) {
    for (let b = 0; b < nBars; b++) {
      const bar = startBar + b;
      const pat = (typeof patterns === 'function' ? patterns(b, bar) : patterns).trim().split(/\s+/);
      if (pat.length !== 16) throw new Error(`${this.name}: baixo com ${pat.length} passos`);
      for (let s = 0; s < 16; s++) {
        const tok = pat[s];
        if (tok === '.' || tok === '-') continue;
        let len = 1;
        while (s + len < 16 && pat[s + len] === '-') len++;
        const c = chordAt(chords, bar, s);
        const base = (o.low ?? midi('E1')) + ((c.bass - ((o.low ?? midi('E1')) % 12)) + 12) % 12;
        const rootM = (o.low ?? midi('E1')) + ((c.root - ((o.low ?? midi('E1')) % 12)) + 12) % 12;
        const third = c.iv.includes(3) ? 3 : c.iv.includes(5) && !c.iv.includes(4) ? 5 : 4;
        const fifth = c.iv.includes(6) ? 6 : c.iv.includes(8) ? 8 : 7;
        const sev = c.iv.includes(11) ? 11 : c.iv.includes(10) ? 10 : c.iv.includes(9) ? 9 : 10;
        let m;
        switch (tok) {
          case 'R': m = base; break;
          case '3': m = rootM + third; break;
          case '4': m = rootM + 5; break;
          case '5': m = rootM + fifth; break;
          case '6': m = rootM + 9; break;
          case '7': m = rootM + sev; break;
          case '8': m = base + 12; break;
          case '9': m = rootM + 14; break;
          case 'A': case 'a': {
            const nb = s + len >= 16 ? chordAt(chords, bar + 1, 0) : chordAt(chords, bar, s + len);
            const nm = (o.low ?? midi('E1')) + ((nb.bass - ((o.low ?? midi('E1')) % 12)) + 12) % 12;
            m = nm + (tok === 'A' ? -1 : 1);
            break;
          }
          case 'x': this.note(deadNote, chan, bar, s, 1, base + 12, (o.vel ?? 0.85) * 0.5); continue;
          default: throw new Error(`${this.name}: símbolo de baixo desconhecido ${tok}`);
        }
        const accent = s % 4 === 0 ? 1 : 0.88;
        this.note(inst, chan, bar, s, len, m, (o.vel ?? 0.85) * accent, { ...o.opts, gate: o.gate ?? 0.85 });
      }
    }
  }

  // Acordes no ritmo: "x..x..x...x.x..." (x toca, - segura, . pausa).
  comp(inst, chan, chords, startBar, nBars, pattern, o = {}) {
    for (let b = 0; b < nBars; b++) {
      const bar = startBar + b;
      const pat = (typeof pattern === 'function' ? pattern(b, bar) : pattern).replace(/\s/g, '');
      for (let s = 0; s < 16; s++) {
        if (pat[s] !== 'x' && pat[s] !== 'X') continue;
        let len = 1;
        while (s + len < 16 && pat[s + len] === '-') len++;
        const c = chordAt(chords, bar, s);
        const notes = voicing(c, o.center ?? midi('G4'), o);
        const vel = (o.vel ?? 0.6) * (pat[s] === 'X' ? 1.15 : 1);
        notes.forEach((m, k) => this.note(inst, chan, bar, s + k * (o.strum ?? 0), len - k * (o.strum ?? 0), m, vel, { ...o.opts, gate: o.gate ?? 0.9 }));
      }
    }
  }

  // Arpejo: 16 símbolos com o índice da nota do acorde (0 = a mais grave), . pausa.
  arp(inst, chan, chords, startBar, nBars, pattern, o = {}) {
    for (let b = 0; b < nBars; b++) {
      const bar = startBar + b;
      const pat = pattern.trim().split(/\s+/);
      for (let s = 0; s < 16; s++) {
        if (pat[s] === '.' || pat[s] === '-') continue;
        let len = 1;
        while (s + len < 16 && pat[s + len] === '-') len++;
        const c = chordAt(chords, bar, s);
        const notes = voicing(c, o.center ?? midi('C5'), { maxNotes: 4, ...o });
        const idx = parseInt(pat[s], 10);
        const m = notes[idx % notes.length] + 12 * Math.floor(idx / notes.length);
        this.note(inst, chan, bar, s, len, m, (o.vel ?? 0.5) * (s % 4 === 0 ? 1 : 0.85), { ...o.opts, gate: o.gate ?? 0.8 });
      }
    }
  }

  // Bateria: { kick: "x...", snare: "...." } (X forte, x normal, o fraca, . nada).
  drums(kit, startBar, nBars, parts) {
    for (let b = 0; b < nBars; b++) {
      const bar = startBar + b;
      for (const [name, pat0] of Object.entries(parts)) {
        const pat = (typeof pat0 === 'function' ? pat0(b, bar) : pat0).replace(/\s/g, '');
        if (!pat) continue;
        const k = kit[name];
        if (!k) throw new Error(`${this.name}: peça ${name} fora do kit`);
        for (let s = 0; s < Math.min(16, pat.length); s++) {
          const c = pat[s];
          if (c === '.') continue;
          const vel = c === 'X' ? 1 : c === 'x' ? 0.75 : 0.38;
          this.hit(k.fn, k.chan, bar, s, vel * (k.vel ?? 1), k.arg);
        }
      }
    }
  }
}

// --- Mixagem, efeitos e master ------------------------------------------------------------

function freeverb(input, { room = 0.82, damp = 0.3, width = 1 } = {}) {
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617];
  const alls = [556, 441, 341, 225];
  const fb = room * 0.28 + 0.7;
  const d = damp * 0.4;
  const n = input.length;
  const outs = [new Float32Array(n), new Float32Array(n)];
  for (let side = 0; side < 2; side++) {
    const spread = side * 23;
    const cb = combs.map((c) => ({ b: new Float32Array(c + spread), i: 0, f: 0 }));
    const ab = alls.map((a) => ({ b: new Float32Array(a + spread), i: 0 }));
    const out = outs[side];
    for (let i = 0; i < n; i++) {
      const x = input[i] * 0.015;
      let y = 0;
      for (const c of cb) {
        const o = c.b[c.i];
        c.f = o * (1 - d) + c.f * d;
        c.b[c.i] = x + c.f * fb;
        if (++c.i >= c.b.length) c.i = 0;
        y += o;
      }
      for (const a of ab) {
        const o = a.b[a.i];
        a.b[a.i] = y + o * 0.5;
        if (++a.i >= a.b.length) a.i = 0;
        y = o - y;
      }
      out[i] = y;
    }
  }
  if (width < 1) {
    for (let i = 0; i < n; i++) {
      const m = (outs[0][i] + outs[1][i]) * 0.5;
      outs[0][i] = m + (outs[0][i] - m) * width;
      outs[1][i] = m + (outs[1][i] - m) * width;
    }
  }
  return outs;
}

function pingpong(inL, inR, time, fb, cutoff) {
  const n = inL.length;
  const D = Math.round(time * SR);
  const bl = new Float32Array(D), br = new Float32Array(D);
  const outL = new Float32Array(n), outR = new Float32Array(n);
  let idx = 0, lpL = 0, lpR = 0;
  const a = 1 - Math.exp(-TAU * cutoff / SR);
  for (let i = 0; i < n; i++) {
    const dl = bl[idx], dr = br[idx];
    outL[i] = dl; outR[i] = dr;
    lpL += a * (dr - lpL); lpR += a * (dl - lpR);
    bl[idx] = (inL[i] + inR[i]) * 0.5 + lpL * fb;
    br[idx] = lpR * fb;
    if (++idx >= D) idx = 0;
  }
  return [outL, outR];
}

function render(song) {
  const loop = Math.round(song.length * SR);
  const pre = Math.round(6 * SR); // só o fim da 1ª passada importa (as caudas)
  const n = pre + loop;
  const L = new Float32Array(n), R = new Float32Array(n), rev = new Float32Array(n);
  const dL = new Float32Array(n), dR = new Float32Array(n);
  const energy = {};
  const peaks = {};
  for (const ev of song.events) {
    const b = ev.drum ? ev.drum(ev.vel, ev.arg) : ev.inst(ev.f, ev.dur, ev.vel, ev.opts);
    const c = ev.chan;
    const th = (c.pan + 1) * Math.PI / 4;
    const gl = Math.cos(th) * c.gain * Math.SQRT2, gr = Math.sin(th) * c.gain * Math.SQRT2;
    let e = 0;
    // Para o relatório: energia "como se ouve" (graves pesam menos, agudos médios mais).
    const kw = new SVF(), ks = new SVF();
    const heard = new Float32Array(b.length);
    for (let i = 0; i < b.length; i++) { kw.run(b[i], 110, 0.6); ks.run(kw.hp, 1800, 0.7); heard[i] = kw.hp + ks.hp * 0.6; }
    // Passada 0: só as caudas que entram no loop. Passada 2: notas adiantadas pela
    // "mão humana" no compasso 1 (tempo negativo) começam no fim do loop.
    for (const pass of [0, 1, 2]) {
      const start = Math.round((ev.t + (pass - 1) * song.length) * SR) + pre;
      if (start + b.length < 0 || start >= n) continue;
      for (let i = 0; i < b.length; i++) {
        const j = start + i;
        if (j < 0 || j >= n) continue;
        const s = b[i];
        L[j] += s * gl; R[j] += s * gr;
        if (c.rev) rev[j] += s * c.gain * c.rev;
        if (c.dly) { dL[j] += s * gl * c.dly; dR[j] += s * gr * c.dly; }
        if (pass === 1) e += heard[i] * heard[i] * c.gain * c.gain;
      }
    }
    const key = c.name ?? '?';
    energy[key] = (energy[key] ?? 0) + e;
    let pk = 0;
    for (let i = 0; i < b.length; i++) pk = Math.max(pk, Math.abs(b[i]));
    peaks[key] = Math.max(peaks[key] ?? 0, pk * c.gain);
  }
  const [rL, rR] = freeverb(rev, song.reverbOpt);
  const dly = song.delayOpt;
  const [eL, eR] = pingpong(dL, dR, dly.time ?? song.six * 3, dly.fb ?? 0.35, dly.cutoff ?? 3500);
  const wet = song.reverbOpt.wet ?? 1;
  for (let i = 0; i < n; i++) {
    L[i] += rL[i] * wet + eL[i];
    R[i] += rR[i] * wet + eR[i];
  }
  return { L, R, start: pre, energy, peaks };
}

function peakOf(L, R) {
  let peak = 0;
  for (let i = 0; i < L.length; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
  return peak || 1;
}

// Master: passa-altas, compressor, volume médio igual em todas e limitador. Roda no
// buffer inteiro (com a cauda da 1ª passada antes de `start`), para o compressor e o
// limitador já estarem "quentes" no começo do loop; depois corta só o loop.
function master(L, R, start) {
  for (const x of [L, R]) highpassInPlace(highpassInPlace(x, 36), 36);
  // Compressor suave (detector RMS ligado nos dois lados), com a mixagem já no pico 1.
  const pre = 1 / peakOf(L.subarray(start), R.subarray(start));
  for (let i = 0; i < L.length; i++) { L[i] *= pre; R[i] *= pre; }
  const thr = Math.pow(10, -20 / 20), ratio = 2.5;
  const atk = Math.exp(-1 / (0.008 * SR)), relc = Math.exp(-1 / (0.16 * SR));
  let envv = 0;
  for (let i = 0; i < L.length; i++) {
    const x = (L[i] * L[i] + R[i] * R[i]) * 0.5;
    envv = x > envv ? atk * envv + (1 - atk) * x : relc * envv + (1 - relc) * x;
    const lvl = Math.sqrt(envv);
    let g = 1;
    if (lvl > thr) g = Math.pow(lvl / thr, 1 / ratio - 1);
    L[i] *= g; R[i] *= g;
  }
  // Todas as faixas no mesmo volume médio (RMS), com os picos segurados pelo limitador.
  const rmsOf = (a, b) => { let s = 0; for (let i = 0; i < a.length; i++) s += a[i] * a[i] + b[i] * b[i]; return Math.sqrt(s / (2 * a.length)); };
  const k = TARGET_RMS / rmsOf(L.subarray(start), R.subarray(start));
  for (let i = 0; i < L.length; i++) { L[i] *= k; R[i] *= k; }
  const reduction = limiter(L, R, 0.89);
  const outL = L.slice(start), outR = R.slice(start);
  return { L: outL, R: outR, rms: rmsOf(outL, outR), reduction };
}

// Volume médio de todas as faixas (-17 dBFS).
const TARGET_RMS = Math.pow(10, -17 / 20);

// Limitador com 2 ms de antecipação: o ganho já baixou quando o pico chega e volta
// devagar. Devolve a maior redução (dB).
function limiter(L, R, ceiling) {
  const n = L.length;
  const look = Math.round(0.002 * SR);
  const need = new Float32Array(n);
  for (let i = 0; i < n; i++) {
    const a = Math.max(Math.abs(L[i]), Math.abs(R[i]));
    need[i] = a > ceiling ? ceiling / a : 1;
  }
  const rel = Math.exp(-1 / (0.08 * SR));
  let g = 1, worst = 1;
  const gains = new Float32Array(n);
  for (let i = n - 1; i >= 0; i--) gains[i] = need[i]; // mínimo da janela à frente
  for (let i = 0; i < n; i++) {
    let m = 1;
    for (let j = i; j < Math.min(n, i + look); j++) if (need[j] < m) m = need[j];
    // Desce em rampa durante a antecipação, sobe devagar depois.
    const target = m;
    g = target < g ? g + (target - g) * (1 / look) * 4 : target + (g - target) * rel;
    g = Math.min(g, need[i]);
    gains[i] = g;
    if (g < worst) worst = g;
  }
  for (let i = 0; i < n; i++) { L[i] *= gains[i]; R[i] *= gains[i]; }
  return -20 * Math.log10(worst);
}

// Volume do mix final por faixa de frequência (dB relativos ao total).
function bands(L, R) {
  const edges = [[0, 90, 'sub'], [90, 300, 'grave'], [300, 1500, 'médio'], [1500, 5000, 'presença'], [5000, 20000, 'brilho']];
  const out = [];
  let total = 0;
  for (const [lo, hi, name] of edges) {
    const a = new SVF(), b = new SVF();
    let e = 0;
    for (let i = 0; i < L.length; i += 1) {
      const x = (L[i] + R[i]) * 0.5;
      let y = x;
      if (lo > 0) { a.run(y, lo, 0.7); y = a.hp; }
      if (hi < 20000) { b.run(y, hi, 0.7); y = b.lp; }
      e += y * y;
    }
    out.push([name, e]); total += e;
  }
  return out.map(([n, e]) => `${n} ${(10 * Math.log10(e / total)).toFixed(1)}`).join(', ');
}

function writeWav(file, L, R) {
  const n = L.length;
  const data = Buffer.alloc(44 + n * 4);
  data.write('RIFF', 0); data.writeUInt32LE(36 + n * 4, 4); data.write('WAVE', 8);
  data.write('fmt ', 12); data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(2, 22);
  data.writeUInt32LE(SR, 24); data.writeUInt32LE(SR * 4, 28); data.writeUInt16LE(4, 32); data.writeUInt16LE(16, 34);
  data.write('data', 36); data.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) {
    data.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(L[i] * 32767))), 44 + i * 4);
    data.writeInt16LE(Math.max(-32767, Math.min(32767, Math.round(R[i] * 32767))), 46 + i * 4);
  }
  fs.writeFileSync(file, data);
}

// Dá nome aos canais (para o relatório de volume de cada um).
function named(chans) { for (const [k, v] of Object.entries(chans)) v.name = k; return chans; }

// ============================================================================================
// FAIXAS
// ============================================================================================

// Menu: city pop / fusion tranquilo, piano elétrico, baixo com slap e um lead macio.
function songMenu() {
  const s = new Song({ name: 'menu', bpm: 108, bars: 16, swing: 0.12, seed: 11, reverb: { room: 0.8, damp: 0.35, wet: 1 }, delay: { fb: 0.3 } });
  const c = named({
    kick: ch(0.85), snare: ch(0.55, 0.05, 0.12), hat: ch(0.22, 0.35, 0.05), shaker: ch(0.12, -0.4, 0.05),
    bass: ch(0.6, 0, 0.02), ep: ch(0.42, -0.2, 0.22), lead: ch(0.33, 0.1, 0.2, 0.25),
    gtr: ch(0.4, 0.45, 0.18, 0.15), pad: ch(0.16, 0, 0.35), crash: ch(0.25, -0.3, 0.2),
  });
  const chords = chordBars(`Abmaj7 | Gm7 | Fm7 | Bb7sus4 Bb7 | Ebmaj7 | Cm7 | Fm7 | Bb7 |
    Abmaj7 | Bbm7 Eb7 | Abmaj7 | Abm6 Db9 | Gm7 | C7 | Fm7 | Bb7sus4 Bb7`);
  const kit = {
    kick: { fn: kick, chan: c.kick }, snare: { fn: snare, chan: c.snare }, hat: { fn: hat, chan: c.hat },
    open: { fn: hat, chan: c.hat, arg: true }, shaker: { fn: shaker, chan: c.shaker }, crash: { fn: crash, chan: c.crash },
  };
  s.drums(kit, 0, 16, {
    kick: (b) => (b % 8 === 7 ? 'x.....x...x.....' : 'x.....x...x.....'),
    snare: (b) => (b % 8 === 7 ? '....x..o.oo.xoxx' : '....x..o....x..o'),
    hat: 'x.x.x.x.x.x.x.x.',
    open: '..............x.',
    shaker: '.x.x.x.x.x.x.x.x',
    crash: (b) => (b % 8 === 0 ? 'x...............' : ''),
  });
  s.bassline(bass, c.bass, chords, 0, 16, (b) =>
    b % 4 === 3 ? 'R . 8 . 5 . R x . R 3 . 5 . 7 A' : 'R . . R 8 . x R . . 5 . 8 . 7 .', { opts: { slap: 0.5, bright: 5 } });
  s.comp(epiano, c.ep, chords, 0, 16, (b) => (b % 2 ? '..x---.x--------' : 'x-----.x---.x---'), { center: midi('A4'), rootless: true, vel: 0.5 });
  s.arp(pluck, c.gtr, chords, 8, 8, '. . 2 . 3 . 1 . . 2 . 3 . . 1 .', { center: midi('E5'), vel: 0.4, opts: { t60: 1.2, bright: 0.4 } });
  s.comp(pad, c.pad, chords, 8, 8, 'x---------------', { center: midi('G4'), rootless: true, vel: 0.5, gate: 1 });
  const leadOpts = { opts: { duty: 0.35, vib: 0.18, cutoff: 3200 }, vel: 0.78 };
  s.melody(lead, c.lead, 0, `C5 3 Eb5 3 G5 2 F5 4 Eb5 2 C5 2 | D5 6 Bb4 2 D5 2 F5 2 G5 4 | Ab5 3 G5 3 F5 2 Eb5 4 C5 4 | Eb5 6 D5 2 r 4 Bb4 2 C5 2 |
    D5 3 Eb5 3 G5 2 Bb5 4 G5 4 | G5 6 Eb5 2 F5 2 Eb5 2 C5 4 | Eb5 3 F5 3 Ab5 2 C6 4 Bb5 2 Ab5 2 | F5 8 D5 4 r 4`, leadOpts);
  s.melody(lead, c.lead, 8, `Eb5 8 G5 4 C6 4 | Db6 6 C6 2 Bb5 4 G5 4 | Ab5 8 G5 4 Eb5 4 | F5 6 Eb5 2 B4 4 Eb5 4 |
    D5 6 F5 2 Bb5 4 G5 4 | E5 6 G5 2 Bb5 4 C6 4 | Ab5 6 G5 2 F5 4 C5 4 | Eb5 4 D5 4 F5 4 Bb4 4`, leadOpts);
  return s;
}

// Circuito Ativos (campo): fusion-rock ensolarado, metais e lead em uníssono.
function songCampo() {
  const s = new Song({ name: 'campo', bpm: 144, bars: 24, seed: 21, reverb: { room: 0.78, damp: 0.3, wet: 0.9 }, delay: { fb: 0.28 } });
  const c = named({
    kick: ch(0.95), snare: ch(0.62, 0.05, 0.14), hat: ch(0.2, 0.35, 0.03), ride: ch(0.14, -0.35, 0.05),
    crash: ch(0.3, -0.3, 0.2), tom: ch(0.5, 0.2, 0.15),
    bass: ch(0.62, 0, 0.02), ep: ch(0.32, -0.35, 0.18), lead: ch(0.3, 0.12, 0.16, 0.18),
    brass: ch(0.26, -0.12, 0.2), chip: ch(0.1, 0.5, 0.1, 0.25), gtr: ch(0.26, 0.5, 0.12), pad: ch(0.13, 0, 0.3),
  });
  const chords = chordBars(`Dmaj9 | Bm7 | Gmaj7 | A7sus4 A7 | Dmaj9 | Bm7 | Gmaj7 | A7sus4 A7 |
    Gmaj7 | A/G | F#m7 | Bm7 | Em7 | F#m7 | Gmaj7 | A7sus4 A7 |
    C/D | D | C/D | D | Bbmaj7 | C | Dsus4 | D`);
  const kit = {
    kick: { fn: kick, chan: c.kick }, snare: { fn: snare, chan: c.snare }, hat: { fn: hat, chan: c.hat },
    open: { fn: hat, chan: c.hat, arg: true }, crash: { fn: crash, chan: c.crash },
    tomH: { fn: tom, chan: c.tom, arg: 170 }, tomL: { fn: tom, chan: c.tom, arg: 105 },
  };
  const fill = (b) => b % 8 === 7;
  s.drums(kit, 0, 24, {
    kick: (b) => (b >= 16 && b < 20 ? 'x..x..x...x..x..' : fill(b) ? 'x.....x.x.......' : 'x.....x.x.....x.'),
    snare: (b) => (fill(b) ? '....x..o..xxxXxX' : '....x..o.o..x..o'),
    hat: (b) => (fill(b) ? 'x.x.x.x.x.......' : 'xoxoxoxoxoxoxoxo'),
    open: (b) => (fill(b) ? '' : '..............x.'),
    tomH: (b) => (b === 23 ? '........xx......' : ''),
    tomL: (b) => (b === 23 ? '..........xx....' : ''),
    crash: (b) => (b % 8 === 0 || b === 20 ? 'X...............' : ''),
  });
  s.bassline(bass, c.bass, chords, 0, 24, (b) => {
    if (b >= 16 && b < 20) return 'R . . R . . R . . R . . 8 . 5 .';
    if (b % 4 === 3) return 'R . R 8 . R 5 . R . 8 . 7 . 5 A';
    return 'R . R 8 x R . R . R 8 . x R 5 .';
  }, { opts: { bright: 6, slap: 0.25 } });
  // Piano elétrico no contratempo, metais nas paradas do refrão, guitarra base.
  s.comp(epiano, c.ep, chords, 0, 16, (b) => (b % 2 ? '..x..x..x...x...' : 'x..x..x...x..x..'), { center: midi('A4'), rootless: true, vel: 0.5 });
  s.comp(pluck, c.gtr, chords, 8, 16, '..x...x...x...x.', { center: midi('D4'), vel: 0.5, strum: 0.08, opts: { t60: 0.5, bright: 0.65 } });
  s.comp(brass, c.brass, chords, 16, 8, (b) => (b < 4 ? 'X..X..X...X.X...' : 'X-------X-------'), { center: midi('F#4'), vel: 0.62 });
  s.comp(pad, c.pad, chords, 8, 8, 'x---------------', { center: midi('A4'), rootless: true, vel: 0.5, gate: 1 });
  s.arp(chip, c.chip, chords, 8, 8, '0 1 2 3 2 1 0 1 2 3 2 1 0 1 2 3', { center: midi('A5'), vel: 0.5, opts: { duty: 0.125 }, gate: 0.6 });
  const A = `A4 2 D5 2 E5 2 F#5 4 E5 2 D5 2 E5 2 | F#5 6 A5 2 F#5 2 E5 2 D5 2 B4 2 | D5 2 E5 2 F#5 2 G5 4 F#5 2 E5 2 D5 2 | E5 6 r 2 C#5 2 D5 2 E5 2 A5 2 |
    A5 4 F#5 2 A5 2 B5 2 A5 2 F#5 2 E5 2 | F#5 4 D5 2 F#5 2 E5 4 D5 2 B4 2 | D5 2 E5 2 G5 2 B5 4 A5 2 G5 2 F#5 2 | E5 2 F#5 2 G5 2 A5 6 r 4`;
  const B = `B5 8 A5 4 F#5 4 | E5 8 C#5 4 E5 4 | A5 6 C#6 2 B5 4 A5 4 | F#5 12 r 4 |
    G5 8 F#5 4 E5 4 | E5 4 F#5 4 A5 4 C#6 4 | B5 6 A5 2 G5 4 F#5 4 | E5 4 D5 2 E5 2 A5 4 G5 4`;
  const C = `G5 2 r 2 G5 2 E5 2 r 2 C5 2 D5 4 | F#5 2 r 2 F#5 2 A5 2 r 2 F#5 2 D5 4 | G5 2 r 2 G5 2 C6 2 r 2 G5 2 E5 4 | F#5 6 E5 2 D5 2 E5 2 F#5 2 A5 2 |
    D6 8 C6 4 A5 4 | C6 4 G5 2 C6 2 E6 8 | D6 8 A5 4 G5 4 | F#5 12 r 4`;
  const leadOpts = { opts: { duty: 0.5, cutoff: 5500, vib: 0.14 }, vel: 0.82 };
  s.melody(lead, c.lead, 0, A, leadOpts);
  s.melody(brass, c.brass, 0, A, { transpose: -12, vel: 0.55, gate: 0.8 }); // uníssono uma oitava abaixo
  s.melody(lead, c.lead, 8, B, { opts: { duty: 0.25, cutoff: 4800, vib: 0.2 }, vel: 0.8 });
  s.melody(lead, c.lead, 16, C, leadOpts);
  return s;
}

// Ilha Ativos (praia): calypso / soca, tambor de aço com rufo, marimba, cavaquinho.
function songPraia() {
  const s = new Song({ name: 'praia', bpm: 126, bars: 24, seed: 31, reverb: { room: 0.7, damp: 0.25, wet: 0.9 }, delay: { fb: 0.25 } });
  const c = named({
    kick: ch(0.85), rim: ch(0.32, 0.25, 0.12), snare: ch(0.55, 0.05, 0.14), hat: ch(0.16, 0.4, 0.04),
    shaker: ch(0.16, -0.45, 0.04), conga: ch(0.45, -0.3, 0.12), bongo: ch(0.32, 0.35, 0.12),
    clave: ch(0.2, 0.15, 0.1), cowbell: ch(0.14, 0.5, 0.08), crash: ch(0.22, -0.3, 0.2),
    bass: ch(0.85, 0, 0.02), pan: ch(0.25, 0.08, 0.22, 0.12), pan2: ch(0.15, -0.35, 0.22),
    marimba: ch(0.3, -0.25, 0.15), uke: ch(0.3, 0.4, 0.1), vibes: ch(0.16, 0.2, 0.3),
  });
  const chords = chordBars(`Fmaj7 | Bb6 | C9 | F6 | Dm7 | Gm7 | C7sus4 C7 | F |
    Bbmaj7 | C/Bb | Am7 | Dm7 | Gm7 | C7 | Am7 D7 | Gm7 C7 |
    Dm7 | Am7 | Bbmaj7 | C7 | Dm7 | Am7 | Bbmaj7 | C7sus4 C7`);
  const kit = {
    kick: { fn: kick, chan: c.kick }, rim: { fn: rim, chan: c.rim }, snare: { fn: snare, chan: c.snare },
    hat: { fn: hat, chan: c.hat, arg: true }, shaker: { fn: shaker, chan: c.shaker },
    conga: { fn: conga, chan: c.conga, arg: 205 }, congaS: { fn: (v) => conga(v, 260, true), chan: c.conga },
    bongo: { fn: conga, chan: c.bongo, arg: 390 }, clave: { fn: woodblock, chan: c.clave, arg: 2300 },
    cowbell: { fn: cowbell, chan: c.cowbell }, crash: { fn: crash, chan: c.crash },
  };
  s.drums(kit, 0, 24, {
    kick: 'x...x...x...x...',
    rim: (b) => (b >= 16 ? '' : '...x..x....x..x.'),
    snare: (b) => (b >= 16 ? '....x.......x...' : b % 8 === 7 ? '..........o.xoxx' : ''),
    hat: '..x...x...x...x.',
    shaker: 'xoxoxoxoxoxoxoxo',
    conga: '......x.x.....x.',
    congaS: '...x.......x....',
    bongo: (b) => (b >= 16 ? 'x.xx..x.x.xx..x.' : ''),
    clave: 'x..x..x...x.x...',
    cowbell: (b) => (b >= 8 && b < 16 ? 'x.x.x.x.x.x.x.x.' : ''),
    crash: (b) => (b % 8 === 0 ? 'x...............' : ''),
  });
  s.bassline(bass, c.bass, chords, 0, 24, (b) =>
    b % 4 === 3 ? 'R . . 5 . . 8 . R . . 3 . 5 . A' : 'R . . 5 . . 8 . R . . 5 . . 8 .', { low: midi('F1'), opts: { bright: 4 } });
  s.comp(pluck, c.uke, chords, 0, 24, '..x.x...x.x...x.', { center: midi('A4'), vel: 0.45, strum: 0.05, gate: 0.4, opts: { t60: 0.6, bright: 0.7 } });
  s.arp(marimba, c.marimba, chords, 8, 8, '0 . 1 2 . 1 3 . 0 . 1 2 . 3 1 .', { center: midi('C5'), vel: 0.55 });
  s.comp(vibes, c.vibes, chords, 16, 8, 'x-------x-------', { center: midi('A4'), rootless: true, vel: 0.45 });
  const A = `C5 3 A4 3 C5 2 F5 4 E5 2 F5 2 | G5 3 F5 3 D5 2 F5 6 r 2 | E5 3 D5 3 C5 2 Bb4 2 C5 2 D5 2 E5 2 | F5 6 r 2 A4 2 C5 2 F5 2 G5 2 |
    A5 3 G5 3 F5 2 A5 4 F5 2 D5 2 | Bb5 3 A5 3 G5 2 F5 4 D5 4 | F5 4 E5 2 D5 2 C5 2 Bb4 2 C5 2 E5 2 | F5 6 r 4 C5 2 D5 2 E5 2`;
  const B = `F5 8 D5 4 F5 4 | G5 8 E5 4 G5 4 | A5 6 G5 2 E5 4 C5 4 | D5 10 r 2 F5 2 A5 2 |
    Bb5 6 A5 2 G5 4 D5 4 | E5 6 G5 2 Bb5 4 C6 4 | A5 4 G5 4 F#5 4 A5 4 | Bb5 4 A5 2 G5 2 E5 4 C5 4`;
  const C = `D5 2 F5 2 A5 2 r 2 G5 2 F5 2 E5 2 r 2 | C5 2 E5 2 G5 2 r 2 A5 2 G5 2 E5 2 r 2 | D5 2 F5 2 A5 2 r 2 Bb5 2 A5 2 F5 2 r 2 | E5 2 G5 2 Bb5 2 r 2 C6 4 r 4 |
    D5 2 F5 2 A5 2 r 2 G5 2 F5 2 E5 2 r 2 | C5 2 E5 2 G5 2 r 2 A5 2 G5 2 E5 2 r 2 | D5 2 F5 2 A5 2 r 2 Bb5 2 A5 2 F5 2 r 2 | F5 4 E5 2 D5 2 C5 2 D5 2 E5 2 G5 2`;
  s.melody(steelpan, c.pan, 0, A, { vel: 0.85, roll: 6 });
  s.melody(steelpan, c.pan, 8, B, { vel: 0.85, roll: 6 });
  // Segunda voz: terças e sextas abaixo, sempre dentro do acorde.
  s.melody(steelpan, c.pan2, 8, `D5 8 Bb4 4 D5 4 | E5 8 C5 4 E5 4 | E5 6 E5 2 C5 4 A4 4 | A4 10 r 2 D5 2 F5 2 |
    G5 6 F5 2 D5 4 Bb4 4 | C5 6 E5 2 G5 4 E5 4 | E5 4 E5 4 D5 4 F#5 4 | G5 4 F5 2 D5 2 C5 4 G4 4`, { vel: 0.7, roll: 6 });
  s.melody(marimba, c.marimba, 16, C, { vel: 0.8 });
  s.melody(steelpan, c.pan, 16, C, { vel: 0.5, transpose: 12 }); // eco agudo
  return s;
}

// Cânion Ativos (deserto): frígia dominante em Mi, violão com tremolo, galope,
// darbuka e castanholas; assobio de faroeste e trompetes.
function songDeserto() {
  const s = new Song({ name: 'deserto', bpm: 136, bars: 24, seed: 41, reverb: { room: 0.88, damp: 0.2, wet: 1 }, delay: { fb: 0.38, cutoff: 2800 } });
  const c = named({
    kick: ch(0.75), snare: ch(0.5, 0.05, 0.18), rim: ch(0.3, 0.2, 0.15), tamb: ch(0.24, 0.45, 0.08),
    cast: ch(0.3, -0.5, 0.12), dum: ch(0.42, -0.2, 0.12), tek: ch(0.3, 0.3, 0.12), crash: ch(0.25, -0.3, 0.25),
    tom: ch(0.5, -0.1, 0.18),
    bass: ch(0.72, 0, 0.03), gtr: ch(0.42, -0.3, 0.3, 0.12), gtr2: ch(0.26, 0.45, 0.25),
    whistle: ch(0.2, 0.15, 0.35, 0.3), trumpet: ch(0.34, 0.1, 0.25, 0.12), trumpet2: ch(0.2, -0.25, 0.25), pad: ch(0.12, 0, 0.4),
  });
  const chords = chordBars(`E | F | E | F | E | F | G F | E |
    Am | G | F | E | Am | G | F | E7 |
    Dm | Am | Dm | E | F | G | F | E`);
  const kit = {
    kick: { fn: kick, chan: c.kick }, snare: { fn: snare, chan: c.snare }, rim: { fn: rim, chan: c.rim },
    tamb: { fn: tambourine, chan: c.tamb }, cast: { fn: castanets, chan: c.cast },
    dum: { fn: dum, chan: c.dum }, tek: { fn: tek, chan: c.tek }, crash: { fn: crash, chan: c.crash },
    tomH: { fn: tom, chan: c.tom, arg: 160 }, tomL: { fn: tom, chan: c.tom, arg: 95 },
  };
  s.drums(kit, 0, 24, {
    kick: (b) => (b < 8 ? 'x.....x.x.......' : 'x.....x.x.....x.'),
    snare: (b) => (b < 8 ? '' : b % 8 === 7 ? '....x.....oxxXxX' : '....x.......x...'),
    rim: (b) => (b < 8 ? '....x.......x...' : ''),
    tamb: (b) => (b < 8 ? '' : '..x...x...x...x.'),
    dum: (b) => (b < 8 || b >= 16 ? 'x.....x...x.....' : ''),
    tek: (b) => (b < 8 || b >= 16 ? '..x.x...x...x.xo' : ''),
    cast: (b) => (b % 4 === 3 ? '............xxx.' : b >= 16 ? '..x...x...x...x.' : ''),
    tomH: (b) => (b === 15 ? '........x.x.....' : ''),
    tomL: (b) => (b === 15 ? '............x.x.' : ''),
    crash: (b) => (b === 8 || b === 16 ? 'X...............' : ''),
  });
  // Galope no baixo: colcheia e duas semicolcheias.
  s.bassline(bass, c.bass, chords, 0, 24, (b) =>
    b < 8 ? 'R . R R R . R R R . R R R . R R' : b % 4 === 3 ? 'R . R R 5 . 5 5 R . R R 8 . 7 A' : 'R . R R 5 . R R R . R R 5 . R R',
  { low: midi('E1'), gate: 0.7, opts: { bright: 3.5 } });
  // Riff de violão (A) e acordes dedilhados (B e C).
  const riff = `E3 2 E3 1 E3 1 F3 2 G#3 2 A3 2 G#3 2 F3 2 E3 2 | F3 2 F3 1 F3 1 G#3 2 A3 2 B3 2 A3 2 G#3 2 F3 2 |
    E3 2 E3 1 E3 1 F3 2 G#3 2 B3 2 C4 2 B3 2 G#3 2 | A3 2 G#3 2 F3 2 E3 2 F3 4 E3 4 |
    E3 2 E3 1 E3 1 F3 2 G#3 2 A3 2 G#3 2 F3 2 E3 2 | F3 2 F3 1 F3 1 G#3 2 A3 2 B3 2 A3 2 G#3 2 F3 2 |
    E3 2 E3 1 E3 1 F3 2 G#3 2 B3 2 C4 2 B3 2 G#3 2 | G3 4 F3 4 E3 8`;
  s.melody(pluck, c.gtr, 0, riff, { vel: 0.85, transpose: 12, opts: { t60: 1.4, bright: 0.75, pick: 0.12, trem: 0.15 } });
  s.arp(pluck, c.gtr, chords, 8, 16, '0 . 1 2 . 1 3 . 0 . 1 2 . 3 2 1', { center: midi('B4'), vel: 0.5, gate: 1, opts: { t60: 1.6, bright: 0.65, trem: 0.12 } });
  s.comp(pluck, c.gtr2, chords, 8, 16, (b) => (b % 2 ? 'x.....x...x.....' : 'x...x...x.x.x...'), { center: midi('E4'), vel: 0.45, strum: 0.12, gate: 0.6, opts: { t60: 0.8, bright: 0.55 } });
  s.comp(pad, c.pad, chords, 16, 8, 'x---------------', { center: midi('A4'), vel: 0.5, gate: 1, att: 0.5 });
  const W = `r 8 B4 4 C5 4 | A4 12 r 4 | r 8 G#4 4 A4 4 | C5 12 B4 4 | r 8 B4 4 D5 4 | C5 8 A4 8 | B4 8 A4 8 | G#4 16`;
  s.melody(whistle, c.whistle, 0, W, { transpose: 12, vel: 0.75, gate: 0.96 });
  const T = `E5 4 A5 4 C6 4 B5 2 A5 2 | B5 6 A5 2 G5 4 D5 4 | A5 4 G5 2 F5 2 E5 4 F5 4 | G#5 12 r 4 |
    C6 4 B5 2 A5 2 E5 4 A5 4 | D6 4 C6 2 B5 2 G5 4 B5 4 | C6 4 A5 4 F5 4 A5 4 | G#5 4 F5 2 E5 2 D5 4 B4 4`;
  const opts = { bright: 1.15 };
  s.melody(brass, c.trumpet, 8, T, { vel: 0.8, opts });
  s.melody(brass, c.trumpet2, 8, `C5 4 E5 4 A5 4 G5 2 E5 2 | G5 6 F5 2 D5 4 B4 4 | F5 4 E5 2 D5 2 C5 4 D5 4 | E5 12 r 4 |
    A5 4 G5 2 E5 2 C5 4 E5 4 | B5 4 A5 2 G5 2 D5 4 G5 4 | A5 4 F5 4 C5 4 F5 4 | E5 4 D5 2 C5 2 B4 4 G#4 4`, { vel: 0.65, opts });
  const C = `F5 6 E5 2 D5 4 A4 4 | C5 6 B4 2 A4 4 E4 4 | D5 4 F5 4 A5 4 G5 2 F5 2 | G#5 8 B5 4 G#5 4 |
    A5 6 G5 2 F5 4 C5 4 | B5 6 A5 2 G5 4 D5 4 | A5 4 C6 4 A5 4 F5 4 | G#5 4 F5 4 E5 8`;
  s.melody(whistle, c.whistle, 16, C, { vel: 0.8, gate: 0.96 });
  return s;
}

// Pico Nevado (neve): guizos, glockenspiel e celesta, pizzicato e vibrafone.
function songNeve() {
  const s = new Song({ name: 'neve', bpm: 132, bars: 24, seed: 51, reverb: { room: 0.9, damp: 0.15, wet: 1.1 }, delay: { fb: 0.33 } });
  const c = named({
    kick: ch(0.85), snare: ch(0.5, 0.05, 0.2), hat: ch(0.15, 0.4, 0.05), sleigh: ch(0.5, -0.35, 0.15),
    crash: ch(0.22, -0.3, 0.25), tom: ch(0.45, 0.1, 0.2),
    bass: ch(0.75, 0, 0.03), glock: ch(0.19, 0.2, 0.3, 0.2), celesta: ch(0.2, -0.15, 0.3),
    pizz: ch(0.5, -0.4, 0.2), vibes: ch(0.18, 0.35, 0.3), pad: ch(0.17, 0, 0.45), flute: ch(0.26, 0.05, 0.35, 0.2),
  });
  const chords = chordBars(`Bm9 | Gmaj7 | D/F# | A6 | Bm9 | Gmaj7 | Em9 | F#7sus4 F#7 |
    Gmaj7 | A6 | F#m7 | Bm7 | Em7 | A7 | Dmaj7 | F#7 |
    Gmaj7 | A6 | Bm7 | Bm7 | Gmaj7 | A6 | Em7 | F#7sus4 F#7`);
  const kit = {
    kick: { fn: kick, chan: c.kick }, snare: { fn: snare, chan: c.snare }, hat: { fn: hat, chan: c.hat },
    sleigh: { fn: sleighbells, chan: c.sleigh }, crash: { fn: crash, chan: c.crash },
    tomH: { fn: tom, chan: c.tom, arg: 180 }, tomL: { fn: tom, chan: c.tom, arg: 110 },
  };
  s.drums(kit, 0, 24, {
    kick: (b) => (b >= 16 ? 'x.......x.......' : 'x.....x.x.......'),
    snare: (b) => (b % 8 === 7 ? '....x.....x.xoXx' : b >= 16 ? '........x.......' : '....x..o....x...'),
    hat: (b) => (b >= 16 ? '' : 'x.x.x.x.x.x.x.x.'),
    sleigh: (b) => (b >= 16 ? 'XoxoXoxoXoxoXoxo' : 'x.o.x.o.x.o.x.o.'),
    tomH: (b) => (b === 23 ? '........xx......' : ''),
    tomL: (b) => (b === 23 ? '..........xx....' : ''),
    crash: (b) => (b % 8 === 0 ? 'x...............' : ''),
  });
  s.bassline(bass, c.bass, chords, 0, 24, (b) =>
    b >= 16 ? 'R - - - - - - . 5 - - - 8 - - .' : b % 4 === 3 ? 'R . . R . . 5 . R . 8 . 5 . 7 A' : 'R . . R . . 8 . R . . 5 . . 8 .',
  { low: midi('E1'), opts: { bright: 2.5 } });
  s.arp(pluck, c.pizz, chords, 0, 16, '0 . 1 . 2 . 3 . 2 . 1 . 2 . 3 .', { center: midi('D5'), vel: 0.5, opts: { t60: 0.35, bright: 0.5, pick: 0.3 } });
  s.comp(vibes, c.vibes, chords, 0, 24, (b) => (b >= 16 ? 'x-------x-------' : '..x-....x-....x-'), { center: midi('F#4'), rootless: true, vel: 0.42 });
  s.comp(pad, c.pad, chords, 8, 16, 'x---------------', { center: midi('A4'), rootless: true, vel: 0.5, gate: 1, att: 0.4 });
  const A = `F#5 2 D5 2 B4 2 C#5 2 D5 4 F#5 4 | G5 2 F#5 2 D5 2 B4 2 F#5 8 | A5 2 F#5 2 D5 2 E5 2 F#5 4 A5 4 | E5 6 C#5 2 F#5 4 E5 4 |
    D6 2 C#6 2 B5 2 A5 2 F#5 4 B5 4 | B5 2 A5 2 G5 2 F#5 2 D5 8 | G5 2 F#5 2 E5 2 F#5 2 G5 4 B5 4 | B5 6 A#5 2 C#6 4 r 4`;
  s.melody(glock, c.glock, 0, A, { vel: 0.75 });
  s.melody(celesta, c.celesta, 0, A, { vel: 0.6, transpose: -12 });
  const B = `B5 8 A5 4 F#5 4 | E5 8 F#5 4 A5 4 | C#6 6 B5 2 A5 4 E5 4 | F#5 10 r 2 D5 2 F#5 2 |
    G5 8 B5 4 E6 4 | C#6 6 B5 2 A5 4 G5 4 | F#5 8 E5 4 D5 4 | A#4 4 C#5 4 E5 4 F#5 4`;
  s.melody(whistle, c.flute, 8, B, { vel: 0.7, gate: 0.95, opts: { vib: 0.14, vibRate: 5, breath: 0.18, scoop: -0.3, tri: 1 } });
  s.melody(glock, c.glock, 8, B, { vel: 0.35, transpose: 12 });
  const C = `D6 2 B5 2 G5 2 B5 2 D6 2 B5 2 G5 2 F#5 2 | E6 2 C#6 2 A5 2 C#6 2 E6 2 C#6 2 A5 2 F#5 2 | F#6 2 D6 2 B5 2 D6 2 F#6 2 D6 2 B5 2 A5 2 | B5 8 r 8 |
    D6 2 B5 2 G5 2 B5 2 D6 2 B5 2 G5 2 F#5 2 | E6 2 C#6 2 A5 2 C#6 2 E6 2 C#6 2 A5 2 F#5 2 | G5 2 B5 2 E6 2 B5 2 G5 2 E5 2 G5 2 B5 2 | B5 4 A#5 4 C#6 4 F#5 4`;
  s.melody(glock, c.glock, 16, C, { vel: 0.7, transpose: -12 });
  s.melody(celesta, c.celesta, 16, C, { vel: 0.5, transpose: -12 });
  return s;
}

// Pódio: fanfarra de metais sobre um groove alegre (na segunda volta os metais
// ganham a segunda voz).
function songPodio() {
  const s = new Song({ name: 'podio', bpm: 112, bars: 16, seed: 61, reverb: { room: 0.82, damp: 0.3 }, delay: { fb: 0.25 } });
  const c = named({
    kick: ch(0.9), snare: ch(0.6, 0.05, 0.16), hat: ch(0.2, 0.35, 0.04), crash: ch(0.3, -0.3, 0.2),
    tamb: ch(0.16, 0.45, 0.08), bass: ch(0.6, 0, 0.02), brass: ch(0.32, 0.05, 0.22), brass2: ch(0.22, -0.3, 0.22),
    ep: ch(0.3, -0.3, 0.18), glock: ch(0.16, 0.4, 0.3, 0.2), pad: ch(0.14, 0, 0.35),
  });
  const chords = chordBars(`C | Am7 | Fmaj7 | G7sus4 G7 | C/E | F | Dm7 | G7 |
    C | Am7 | Fmaj7 | G7sus4 G7 | C/E | F | Dm7 | G7`);
  const kit = {
    kick: { fn: kick, chan: c.kick }, snare: { fn: snare, chan: c.snare }, hat: { fn: hat, chan: c.hat },
    crash: { fn: crash, chan: c.crash }, tamb: { fn: tambourine, chan: c.tamb },
  };
  s.drums(kit, 0, 16, {
    kick: 'x.....x.x.......',
    snare: (b) => (b % 8 === 7 ? '....x...x.xxXxXx' : '....x.......x...'),
    hat: 'x.x.x.x.x.x.x.x.',
    tamb: (b) => (b >= 8 ? '....x.......x...' : ''),
    crash: (b) => (b % 8 === 0 ? 'X...............' : ''),
  });
  s.bassline(bass, c.bass, chords, 0, 16, 'R . . R 8 . R . . R . R 5 . 8 .', { opts: { bright: 4, slap: 0.3 } });
  s.comp(epiano, c.ep, chords, 0, 16, 'x..x..x...x..x..', { center: midi('G4'), rootless: true, vel: 0.5 });
  s.comp(pad, c.pad, chords, 8, 8, 'x---------------', { center: midi('E4'), vel: 0.5, gate: 1 });
  const P = `G4 2 C5 2 E5 2 G5 6 E5 2 G5 2 | A5 8 G5 4 E5 4 | F5 2 A5 2 C6 6 A5 2 F5 4 | C6 4 B5 4 G5 8 |
    E5 2 G5 2 C6 2 E6 6 D6 2 C6 2 | C6 8 A5 4 F5 4 | F5 4 A5 4 D6 4 C6 4 | B5 4 D6 4 G5 8`;
  s.melody(brass, c.brass, 0, P, { vel: 0.85, transpose: -12 });
  s.melody(brass, c.brass, 8, P, { vel: 0.85, transpose: -12 });
  s.melody(brass, c.brass2, 8, `E4 2 G4 2 C5 2 E5 6 C5 2 E5 2 | E5 8 E5 4 C5 4 | C5 2 F5 2 A5 6 F5 2 C5 4 | A5 4 G5 4 D5 8 |
    C5 2 E5 2 G5 2 C6 6 B5 2 G5 2 | A5 8 F5 4 C5 4 | D5 4 F5 4 A5 4 A5 4 | G5 4 B5 4 D5 8`, { vel: 0.7, transpose: -12 });
  s.melody(glock, c.glock, 8, P, { vel: 0.5 });
  return s;
}

const SONGS = { menu: songMenu, campo: songCampo, praia: songPraia, deserto: songDeserto, neve: songNeve, podio: songPodio };

// --- Execução ---------------------------------------------------------------------------

function main() {
  const args = process.argv.slice(2);
  let wavDir = null;
  const names = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--wav') wavDir = args[++i];
    else names.push(args[i]);
  }
  const list = names.length ? names : Object.keys(SONGS);
  fs.mkdirSync(OUT_DIR, { recursive: true });
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'ativos-music-'));
  for (const name of list) {
    if (!SONGS[name]) throw new Error(`faixa desconhecida: ${name}`);
    const t0 = Date.now();
    const song = SONGS[name]();
    const mix = render(song);
    const { L, R, rms, reduction } = master(mix.L, mix.R, mix.start);
    const energy = mix.energy;
    const wav = path.join(wavDir ?? tmp, `${name}.wav`);
    if (wavDir) fs.mkdirSync(wavDir, { recursive: true });
    writeWav(wav, L, R);
    const ogg = path.join(OUT_DIR, `${name}.ogg`);
    execFileSync('ffmpeg', ['-hide_banner', '-loglevel', 'error', '-y', '-i', wav, '-c:a', 'vorbis', '-strict', '-2', '-q:a', '3', ogg]);
    const total = Object.values(energy).reduce((a, b) => a + b, 0);
    const channels = Object.entries(energy).sort((a, b) => b[1] - a[1])
      .map(([k, e]) => `${k} ${(10 * Math.log10(e / total)).toFixed(1)}`).join(', ');
    console.log(`${name}: ${song.length.toFixed(1)} s, ${song.bpm} bpm, ${song.events.length} notas, RMS ${(20 * Math.log10(rms)).toFixed(1)} dBFS (limitador -${reduction.toFixed(1)} dB), ` +
      `${(fs.statSync(ogg).size / 1024).toFixed(0)} KB, ${((Date.now() - t0) / 1000).toFixed(1)} s\n   canais (dB): ${channels}\n   bandas (dB): ${bands(L, R)}`);
  }
  fs.rmSync(tmp, { recursive: true, force: true });
}

main();
