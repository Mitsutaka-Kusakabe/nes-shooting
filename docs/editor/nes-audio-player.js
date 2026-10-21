/**
 * nes-audio-player.js
 * MOJAxMOJA WARS - Famicom / NES 2A03 APU Web Audio Synthesis & Sequencer Engine
 * 
 * Supports:
 * - Pulse 1 (Melody) with Duty Cycles (12.5%, 25%, 50%, 75%) via PeriodicWave
 * - Pulse 2 (Harmony / SFX)
 * - Triangle (Bass) 16-step staircase wave / 1-octave lower tuning
 * - DMC (DPCM Drums) authentic Kick ($C000) & Snare ($C3C0) delta-modulated samples
 * - Noise (15-bit Galois LFSR NES authentic noise for Hi-hats & Snares)
 * - Interactive startNote / stopNote / previewNote with piano keyboard glissando
 * - Ca65 assembly (.byte) exporter & parser
 * - .nesbgm.json project save & load
 * - Built-in presets for Stage 1, Boss, Title, and Game Over themes
 */

(function (global) {
  'use strict';

  // 12 semitones & note name mapping (Index 1 = A1 = MIDI 33, Index 37 = A4 = MIDI 69)
  const NOTE_NAMES = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  const MIDI_BASE = 32; // index 1 = MIDI 33
  const HOLD = 0xFF;
  const REST = 0x00;

  function noteIdxToMidi(idx) {
    if (!idx || idx <= 0 || idx > 64) return null;
    return idx + MIDI_BASE;
  }

  function midiToFreq(midi) {
    return 440.0 * Math.pow(2.0, (midi - 69.0) / 12.0);
  }

  function noteIdxToFreq(idx) {
    const midi = noteIdxToMidi(idx);
    if (!midi) return 0;
    return midiToFreq(midi);
  }

  function noteIdxToName(idx) {
    if (idx === HOLD) return '-';
    if (!idx || idx <= 0) return '.';
    const midi = noteIdxToMidi(idx);
    if (!midi) return '.';
    const name = NOTE_NAMES[midi % 12];
    const oct = Math.floor(midi / 12) - 1;
    return `${name}${oct}`;
  }

  function nameToNoteIdx(str) {
    if (!str || str === '.' || str === 'REST') return REST;
    if (str === '-' || str === 'HOLD') return HOLD;
    const m = str.trim().match(/^([A-Ga-g])([#b]?)(-?\d+)$/);
    if (!m) return REST;
    let name = m[1].toUpperCase();
    let acc = m[2];
    let oct = parseInt(m[3], 10);
    let semi = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[name];
    if (acc === '#') semi++;
    else if (acc === 'b') semi--;
    let midi = (oct + 1) * 12 + semi;
    let idx = midi - MIDI_BASE;
    if (idx < 1 || idx > 64) return REST;
    return idx;
  }

  // Pre-calculated period tables for Pulse & Triangle (NTSC 1.789773 MHz)
  const CPU_FREQ = 1789773.0;
  const PERIOD_TABLE_LO = new Uint8Array(65);
  const PERIOD_TABLE_HI = new Uint8Array(65);
  for (let idx = 1; idx <= 64; idx++) {
    const freq = noteIdxToFreq(idx);
    const period = Math.round(CPU_FREQ / (16.0 * freq) - 1.0);
    PERIOD_TABLE_LO[idx] = period & 0xFF;
    PERIOD_TABLE_HI[idx] = (period >> 8) & 0x07;
  }

  // Delta Modulation (DPCM) Sample Bytes (Kick & Snare from TR-808 NES)
  function decodeDmc(bytes) {
    let out = new Float32Array(bytes.length * 8);
    let level = 64; // NES APU 7-bit counter initial level (0..127)
    let p = 0;
    for (let i = 0; i < bytes.length; i++) {
      let b = bytes[i];
      for (let bit = 0; bit < 8; bit++) {
        if ((b >> bit) & 1) {
          if (level <= 125) level += 2;
        } else {
          if (level >= 2) level -= 2;
        }
        out[p++] = (level - 64) / 64.0;
      }
    }
    return out;
  }

  const DMC_KICK_HEX = "ffbfffe5d6ba524110201200080004144a45455dbb6f7bedf7f7f7fdfbbdbb65a954a9244841004411084108924295555b5b66dbbb7be77bdd7bb7b7dbb6b55a55954a4992442211111111894492a4a452a56a556bad6ddbb6db6eb7db6ddbb66d6db55a5555552aa5949424499224912449929292522a55a9aaaa55add65a5b5bdbd6b66d6d5bdbda5a6bb56a55adaa5255a9542aa59494949294949492524a29954a95aaaaaaaa5ab56ab5566badb5b6d65a6badb556abd56a55adaaaaaaaa54952a954aa5524aa59452299552a9542a55a94a555555555555adaa55ad5aad56abd56ab55aabd5aad5aa55adaa555555ad4a555555aa2a55a952a54aa54aa54aa54aa54a55aa5255aaaa4a55555555adaaaa55d5aa56b5aa55ab56ad5ab5aa55ad6a55adaa6a5555555555555595aaaa5455aa4a55aa5295aa54a52a55a5aa5455a9aaaa2a55555555adaaaaaa5555adaa56d5aa5a55ab6a55adaa5655abaa6a55555555555555555555a5aaaa5455a5aa5255a9aa5455aaaa5455a5aaaa2a555555555555555555adaaaa6a5555abaa5a55b5aaaa5555adaaaa555555d5aaaaaaaaaa4a55555595aaaa4a5555a9aa2a5555a5aaaa5255555555aaaaaaaa5a55555555abaaaa5a5555adaaaa5a5555d5aaaaaa6a555555555555555555aaaaaaaa54555595aaaaaa52555555aaaaa545555555555555555555555abaaaaaa5a555555b5aaaaaaaa5555555555abaaaaaaaa2a5555555555a5aaaaaa525555555595aaaaaaaaaaaa5a5555555555adaaaaaa555555555555555555555555555555555555a9aaaaaa2a55555555555555a5aaaaaaaa6a555555555555555555abaaaaaaaa5555555555555555555555555555555555a5aaaaaaaa2a55555555555555555555555555555555b5aaaaaaaaaaaaaa5a555555555555555595aaaaaaaaaaaa2a555555555555555555555555555555555555abaaaaaaaaaaaaaaaaaaaaaaaaaa5255555555555555555555555555abaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa4a55555555555555555555b5aaaaaaaaaaaaaaaaaaaaaa5555";
  const DMC_SNARE_HEX = "96266dfff9abdc641306010218818688d54adffbb7ef1df03feaac8d00218999a386e4b038ec3967eaef53e5e6e6c54cc8128813c4859ea96ab92eba5cfa65cc22edc6075e46a8e6446ee76078d479e2efc5c897153ca1da1a262c646f583b0fcf26e86a2f149d13e704b5b35a64866d49dba4b2b2d827932be3f90e0dae149629df12590eda6d6a2c673ab9285eae68a7788c0d369cc7519a1772353a6cd833356bac1375a5532a6aa7381e8e9acd6c4d925a5bac99854d69bd30723c7ad23ce8d1c6e496d8746c1397394535871d3ab1a55b7496b1518b9d3af444654ea76c69981da7388b5db4d26578563455d5cab2992acbca255575d1d2581bab74995c524dcd45ad5435a7c9322b55ab31abb4aac62acb54ab4aad31ad66a6a6ca2ab5d431d3aa52ada9aacab2acaa6aacaccaaa2ccb2aabacccaacaaaca32b3b4aaaa2aabacaacaaa2a4babaa2ad52cb5b42ccbb4b4b22cabaaca2a4bcdaacab2cab2ac2ab3b2aaaaaaaa2aabaaaa32b3acaaacaca4cabaa2cabaa34abaaaaaaaaacaaaa2aabaaaaaaaaaaaaaaaaaaaaaaaaaa2aabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

  function hexToBytes(hex) {
    let bytes = new Uint8Array(hex.length / 2);
    for (let i = 0; i < bytes.length; i++) {
      bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
    }
    return bytes;
  }

  /**
   * NesAudioPlayer Class
   */
  class NesAudioPlayer {
    constructor() {
      this.ctx = null;
      this.masterGain = null;
      this.volume = 0.85;
      this.periodicWaves = {}; // 0: 12.5%, 1: 25%, 2: 50%, 3: 75%
      this.triangleWave = null;
      this.noiseBuffer = null;
      this.kickBuffer = null;
      this.snareBuffer = null;

      // Sequencer state
      this.isPlaying = false;
      this.isPaused = false;
      this.currentSong = null;
      this.orderIdx = 0;
      this.barStep = 0; // 0..15
      this.timerId = null;
      this.nextStepAudioTime = 0;
      this.lookaheadMs = 25;
      this.scheduleAheadSec = 0.12;

      // Callbacks
      this.onStep = null; // (orderIdx, barStep, totalStep, audioTime)
      this.onBar = null;  // (orderIdx)
      this.onStop = null; // ()

      // Channel Mute & Volume State
      this.channelState = {
        pulse1: { mute: false, vol: 13, duty: 2 }, // duty: 2 = 50%
        pulse2: { mute: false, vol: 11, duty: 2 },
        triangle: { mute: false, vol: 15 },
        noise: { mute: false, vol: 11 },
        dmc: { mute: false, vol: 15 }
      };

      // Active interactive voice tracking for piano roll preview
      this.activeVoices = {};

      // Auto-unlock audio on any page interaction
      if (typeof window !== 'undefined') {
        const unlock = () => {
          this.initAudio();
          window.removeEventListener('pointerdown', unlock);
          window.removeEventListener('keydown', unlock);
        };
        window.addEventListener('pointerdown', unlock, { passive: true });
        window.addEventListener('keydown', unlock, { passive: true });
      }
    }

    /**
     * Initialize Web Audio Context on user gesture
     */
    initAudio() {
      if (!this.ctx) {
        const AudioCtx = window.AudioContext || window.webkitAudioContext;
        this.ctx = new AudioCtx();
        this.masterGain = this.ctx.createGain();
        this.masterGain.gain.setValueAtTime(this.volume, this.ctx.currentTime);
        this.masterGain.connect(this.ctx.destination);

        this._initPeriodicWaves();
        this._initNoiseBuffer();
        this._initDmcBuffers();
      }
      if (this.ctx && this.ctx.state === 'suspended') {
        this.ctx.resume();
      }
    }

    _initPeriodicWaves() {
      const duties = [0.125, 0.25, 0.50, 0.75];
      const nTerms = 64;
      duties.forEach((d, idx) => {
        const real = new Float32Array(nTerms);
        const imag = new Float32Array(nTerms);
        for (let n = 1; n < nTerms; n++) {
          // Pure cosine harmonic series for pulse wave (symmetric around 0)
          real[n] = (2.0 / (n * Math.PI)) * Math.sin(n * Math.PI * d);
          imag[n] = 0.0;
        }
        try {
          this.periodicWaves[idx] = this.ctx.createPeriodicWave(real, imag, { disableNormalization: false });
        } catch (e) {
          console.warn('createPeriodicWave fallback for duty', d, e);
        }
      });
    }

    _initNoiseBuffer() {
      const length = 32767;
      const buffer = this.ctx.createBuffer(1, length, this.ctx.sampleRate);
      const data = buffer.getChannelData(0);
      let shift = 1;
      for (let i = 0; i < length; i++) {
        let bit = (shift ^ (shift >> 1)) & 1;
        shift = (shift >> 1) | (bit << 14);
        data[i] = ((shift & 1) ? 1.0 : -1.0) * 0.7;
      }
      this.noiseBuffer = buffer;
    }

    _initDmcBuffers() {
      try {
        const kickBytes = hexToBytes(DMC_KICK_HEX);
        const kickPcm = decodeDmc(kickBytes);
        this.kickBuffer = this.ctx.createBuffer(1, kickPcm.length, 33144);
        this.kickBuffer.getChannelData(0).set(kickPcm);

        const snareBytes = hexToBytes(DMC_SNARE_HEX);
        const snarePcm = decodeDmc(snareBytes);
        this.snareBuffer = this.ctx.createBuffer(1, snarePcm.length, 37287);
        this.snareBuffer.getChannelData(0).set(snarePcm);
      } catch (e) {
        console.warn('DMC sample initialization warning:', e);
      }
    }

    setMasterVolume(val) {
      this.volume = Math.max(0, Math.min(1, val));
      if (this.masterGain && this.ctx) {
        this.masterGain.gain.setValueAtTime(this.volume, this.ctx.currentTime);
      }
    }

    // =========================================================================
    // Real-Time Note Audition & Piano Keyboard Glissando
    // =========================================================================
    startNote(channel, noteIdx) {
      this.initAudio();
      if (!this.ctx) return;
      this.stopNote(channel);

      const now = this.ctx.currentTime;
      const chState = this.channelState[channel] || { duty: 2, vol: 12 };
      const vol = chState.vol !== undefined ? chState.vol : 12;

      if (channel === 'pulse1' || channel === 'pulse2') {
        const freq = noteIdxToFreq(noteIdx);
        if (freq <= 0) return;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        const duty = chState.duty || 2;
        if (this.periodicWaves[duty]) {
          osc.setPeriodicWave(this.periodicWaves[duty]);
        } else {
          osc.type = 'square';
        }
        osc.frequency.setValueAtTime(freq, now);

        const targetGain = Math.max(0.01, (vol / 15.0) * 0.38);
        gain.gain.setValueAtTime(0.001, now);
        gain.gain.linearRampToValueAtTime(targetGain, now + 0.005);

        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(now);
        this.activeVoices[channel] = { osc, gain, noteIdx };
      } else if (channel === 'triangle') {
        const freq = noteIdxToFreq(noteIdx) * 0.5; // 1 octave lower
        if (freq <= 0) return;
        const osc = this.ctx.createOscillator();
        const gain = this.ctx.createGain();
        osc.type = 'triangle';
        osc.frequency.setValueAtTime(freq, now);

        const targetGain = 0.45;
        gain.gain.setValueAtTime(0.001, now);
        gain.gain.linearRampToValueAtTime(targetGain, now + 0.005);

        osc.connect(gain);
        gain.connect(this.masterGain);
        osc.start(now);
        this.activeVoices[channel] = { osc, gain, noteIdx };
      } else if (channel === 'noise') {
        this.triggerNoiseHit(now, 0.06, 0.25);
      } else if (channel === 'dmc') {
        if (noteIdx === 1) this.triggerKick(now);
        else if (noteIdx === 2) this.triggerSnare(now);
      }
    }

    stopNote(channel) {
      if (this.activeVoices[channel]) {
        try {
          const v = this.activeVoices[channel];
          const now = this.ctx ? this.ctx.currentTime : 0;
          if (v.gain && this.ctx) {
            v.gain.gain.cancelScheduledValues(now);
            v.gain.gain.setValueAtTime(v.gain.gain.value, now);
            v.gain.gain.linearRampToValueAtTime(0.0001, now + 0.025);
          }
          if (v.osc) v.osc.stop(now + 0.03);
        } catch (e) {}
        delete this.activeVoices[channel];
      }
    }

    previewNote(channel, noteIdx, durationSec = 0.35) {
      this.initAudio();
      if (!this.ctx) return;
      this.startNote(channel, noteIdx);
      setTimeout(() => {
        this.stopNote(channel);
      }, durationSec * 1000);
    }

    triggerKick(time) {
      this.initAudio();
      if (!this.kickBuffer || this.channelState.dmc.mute) return;
      const src = this.ctx.createBufferSource();
      const gain = this.ctx.createGain();
      src.buffer = this.kickBuffer;
      gain.gain.setValueAtTime(0.85 * (this.channelState.dmc.vol / 15.0), time);
      src.connect(gain);
      gain.connect(this.masterGain);
      src.start(time);
    }

    triggerSnare(time) {
      this.initAudio();
      if (!this.snareBuffer || this.channelState.dmc.mute) return;
      const src = this.ctx.createBufferSource();
      const gain = this.ctx.createGain();
      src.buffer = this.snareBuffer;
      gain.gain.setValueAtTime(0.75 * (this.channelState.dmc.vol / 15.0), time);
      src.connect(gain);
      gain.connect(this.masterGain);
      src.start(time);
    }

    triggerNoiseHit(time, duration = 0.05, vol = 0.2) {
      this.initAudio();
      if (!this.noiseBuffer || this.channelState.noise.mute) return;
      const src = this.ctx.createBufferSource();
      const gain = this.ctx.createGain();
      src.buffer = this.noiseBuffer;
      src.loop = true;
      gain.gain.setValueAtTime(vol * (this.channelState.noise.vol / 15.0), time);
      gain.gain.linearRampToValueAtTime(0.0001, time + duration);
      src.connect(gain);
      gain.connect(this.masterGain);
      src.start(time);
      src.stop(time + duration);
    }

    // =========================================================================
    // Sequencer Playback Core
    // =========================================================================
    playSong(songData, startOrderIdx = 0, startStep = 0) {
      this.initAudio();
      this.stop(false); // 曲切替時は onStop コールバックを発火させない

      this.currentSong = songData;
      this.orderIdx = startOrderIdx;
      this.barStep = startStep;
      this.isPlaying = true;
      this.isPaused = false;
      this.nextStepAudioTime = this.ctx.currentTime + 0.05;

      this._activePulse1 = null;
      this._activePulse2 = null;
      this._activeTriangle = null;

      this.timerId = setInterval(() => this._scheduler(), this.lookaheadMs);
    }

    pause() {
      if (!this.isPlaying || this.isPaused) return;
      this.isPaused = true;
      if (this.timerId) clearInterval(this.timerId);
      this._cutAllAudio();
    }

    resume() {
      if (!this.isPlaying || !this.isPaused) return;
      this.initAudio();
      this.isPaused = false;
      this.nextStepAudioTime = this.ctx.currentTime + 0.05;
      this.timerId = setInterval(() => this._scheduler(), this.lookaheadMs);
    }

    stop(triggerCallback = true) {
      if (this.timerId) {
        clearInterval(this.timerId);
        this.timerId = null;
      }
      if (!this.isPlaying && !this.isPaused) return;
      this.isPlaying = false;
      this.isPaused = false;
      this._cutAllAudio();
      if (triggerCallback && this.onStop) this.onStop();
    }

    seek(orderIdx, barStep = 0) {
      this.orderIdx = orderIdx;
      this.barStep = barStep;
      this._cutAllAudio();
      if (this.isPlaying && !this.isPaused) {
        this.nextStepAudioTime = this.ctx.currentTime + 0.02;
      }
    }

    _cutAllAudio() {
      ['pulse1', 'pulse2', 'triangle'].forEach(ch => this.stopNote(ch));
      if (this._activePulse1) {
        try { this._activePulse1.osc.stop(); } catch (e) {}
        this._activePulse1 = null;
      }
      if (this._activePulse2) {
        try { this._activePulse2.osc.stop(); } catch (e) {}
        this._activePulse2 = null;
      }
      if (this._activeTriangle) {
        try { this._activeTriangle.osc.stop(); } catch (e) {}
        this._activeTriangle = null;
      }
    }

    _scheduler() {
      if (!this.isPlaying || this.isPaused) return;
      const tempo = this.currentSong ? (this.currentSong.tempoFrames || 6) : 6;
      const stepDuration = (tempo / 60.0988);

      while (this.nextStepAudioTime < this.ctx.currentTime + this.scheduleAheadSec) {
        this._scheduleStep(this.orderIdx, this.barStep, this.nextStepAudioTime, stepDuration);
        this.nextStepAudioTime += stepDuration;

        const curOrder = this.orderIdx;
        const curStep = this.barStep;
        const callTime = this.nextStepAudioTime;
        setTimeout(() => {
          if (this.isPlaying && this.onStep) {
            this.onStep(curOrder, curStep, curOrder * 16 + curStep, callTime);
          }
        }, Math.max(0, (callTime - this.ctx.currentTime) * 1000 - 15));

        this.barStep++;
        if (this.barStep >= 16) {
          this.barStep = 0;
          this.orderIdx++;
          const order = this.currentSong.order || [];
          if (this.orderIdx >= order.length || order[this.orderIdx] === '$FF' || order[this.orderIdx] === 255) {
            this.orderIdx = this.currentSong.loopOrderIndex || 0;
          }
          if (this.onBar) {
            const nextO = this.orderIdx;
            setTimeout(() => this.onBar(nextO), 0);
          }
        }
      }
    }

    _scheduleStep(orderIdx, step, time, duration) {
      if (!this.currentSong) return;
      const order = this.currentSong.order || [];
      const patKey = order[orderIdx];
      const patterns = this.currentSong.patterns || {};
      const pat = patterns[patKey];
      if (!pat) return;

      const melIdx = pat.mel ? pat.mel[step] : REST;
      const bassIdx = pat.bass ? pat.bass[step] : REST;
      const drumVal = pat.drums ? pat.drums[step] : 0;
      const harmIdx = pat.harm ? pat.harm[step] : REST;

      // 1. Pulse 1 (Melody)
      this._scheduleMelody(melIdx, time, duration);

      // 2. Pulse 2 (Harmony)
      if (pat.harm) {
        this._scheduleHarmony(harmIdx, time, duration);
      }

      // 3. Triangle (Bass)
      this._scheduleBass(bassIdx, time, duration);

      // 4. Drums (DMC Kick / Snare)
      if (drumVal === 1) {
        this.triggerKick(time);
      } else if (drumVal === 2) {
        this.triggerSnare(time);
      }

      // 5. Automatic Noise Hi-hat
      if (!this.currentSong.disableNoiseHat && !this.channelState.noise.mute) {
        const isOdd = (step & 1) !== 0;
        this.triggerNoiseHit(time, isOdd ? 0.025 : 0.035, isOdd ? 0.09 : 0.16);
      }
    }

    _scheduleMelody(noteIdx, time, duration) {
      if (noteIdx === HOLD) return;
      if (this._activePulse1) {
        try {
          this._activePulse1.gain.gain.setValueAtTime(this._activePulse1.vol, time);
          this._activePulse1.gain.gain.linearRampToValueAtTime(0.0001, time + 0.005);
          this._activePulse1.osc.stop(time + 0.006);
        } catch (e) {}
        this._activePulse1 = null;
      }
      if (noteIdx === REST || this.channelState.pulse1.mute) return;

      const freq = noteIdxToFreq(noteIdx);
      if (freq <= 0) return;

      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      const duty = this.channelState.pulse1.duty || 2;
      if (this.periodicWaves[duty]) {
        osc.setPeriodicWave(this.periodicWaves[duty]);
      } else {
        osc.type = 'square';
      }
      osc.frequency.setValueAtTime(freq, time);

      const targetVol = (this.channelState.pulse1.vol / 15.0) * 0.35;
      gain.gain.setValueAtTime(targetVol, time);
      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(time);
      this._activePulse1 = { osc, gain, vol: targetVol };
    }

    _scheduleHarmony(noteIdx, time, duration) {
      if (noteIdx === HOLD) return;
      if (this._activePulse2) {
        try {
          this._activePulse2.gain.gain.setValueAtTime(this._activePulse2.vol, time);
          this._activePulse2.gain.gain.linearRampToValueAtTime(0.0001, time + 0.005);
          this._activePulse2.osc.stop(time + 0.006);
        } catch (e) {}
        this._activePulse2 = null;
      }
      if (noteIdx === REST || this.channelState.pulse2.mute) return;

      const freq = noteIdxToFreq(noteIdx);
      if (freq <= 0) return;

      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      const duty = this.channelState.pulse2.duty || 2;
      if (this.periodicWaves[duty]) {
        osc.setPeriodicWave(this.periodicWaves[duty]);
      } else {
        osc.type = 'square';
      }
      osc.frequency.setValueAtTime(freq, time);

      const targetVol = (this.channelState.pulse2.vol / 15.0) * 0.28;
      gain.gain.setValueAtTime(targetVol, time);
      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(time);
      this._activePulse2 = { osc, gain, vol: targetVol };
    }

    _scheduleBass(noteIdx, time, duration) {
      if (noteIdx === HOLD) return;
      if (this._activeTriangle) {
        try {
          this._activeTriangle.gain.gain.setValueAtTime(0.42, time);
          this._activeTriangle.gain.gain.linearRampToValueAtTime(0.0001, time + 0.004);
          this._activeTriangle.osc.stop(time + 0.005);
        } catch (e) {}
        this._activeTriangle = null;
      }
      if (noteIdx === REST || this.channelState.triangle.mute) return;

      const freq = noteIdxToFreq(noteIdx) * 0.5; // 1 octave lower
      if (freq <= 0) return;

      const osc = this.ctx.createOscillator();
      const gain = this.ctx.createGain();
      osc.type = 'triangle';
      osc.frequency.setValueAtTime(freq, time);

      const targetVol = 0.42;
      gain.gain.setValueAtTime(targetVol, time);
      osc.connect(gain);
      gain.connect(this.masterGain);

      osc.start(time);
      this._activeTriangle = { osc, gain, vol: targetVol };
    }

    // =========================================================================
    // ca65 Assembly (.s) Exporter & Parser
    // =========================================================================
    exportAsm(song, prefix = 'stg') {
      const p = prefix;
      let lines = [];
      lines.push(`; ${song.title || 'NES BGM Track'}`);
      lines.push(`; Exported by MOJAxMOJA WARS Web Music Editor`);
      lines.push(`.segment "RODATA"`);
      lines.push(``);
      lines.push(`${p}_LOOP = ${song.loopOrderIndex || 0}`);
      lines.push(`${p}_order:`);

      const order = song.order || [];
      const orderChunk = [];
      order.forEach((key) => {
        const patKeys = Object.keys(song.patterns || {});
        const pIdx = patKeys.indexOf(key);
        orderChunk.push(pIdx >= 0 ? pIdx : 0);
      });
      orderChunk.push('$FF');

      for (let i = 0; i < orderChunk.length; i += 16) {
        const slice = orderChunk.slice(i, i + 16);
        lines.push(`    .byte ` + slice.map(x => (x === '$FF' ? '$FF' : x.toString())).join(', '));
      }
      lines.push(``);

      const patKeys = Object.keys(song.patterns || {});
      lines.push(`${p}_pat_lo:`);
      lines.push(`    .byte ` + patKeys.map(k => `<${p}_pat_${k}`).join(', '));
      lines.push(`${p}_pat_hi:`);
      lines.push(`    .byte ` + patKeys.map(k => `>${p}_pat_${k}`).join(', '));
      lines.push(``);

      patKeys.forEach(k => {
        const pat = song.patterns[k];
        lines.push(`${p}_pat_${k}:`);
        const mel = (pat.mel || new Array(16).fill(0)).map(v => '$' + ('0' + v.toString(16).toUpperCase()).slice(-2));
        lines.push(`    .byte ` + mel.join(', '));
        const bass = (pat.bass || new Array(16).fill(0)).map(v => '$' + ('0' + v.toString(16).toUpperCase()).slice(-2));
        lines.push(`    .byte ` + bass.join(', '));
        const drums = (pat.drums || new Array(16).fill(0)).map(v => '$' + ('0' + v.toString(16).toUpperCase()).slice(-2));
        lines.push(`    .byte ` + drums.join(', '));
      });

      return lines.join('\n');
    }

    parseAsm(asmText) {
      const song = {
        title: 'Imported ASM Track',
        tempoFrames: 6,
        loopOrderIndex: 0,
        order: [],
        patterns: {}
      };

      const lines = asmText.split(/\r?\n/);
      let curPatName = null;
      let patData = [];
      let patOrderIndices = [];
      let patNamesInOrder = [];

      for (let line of lines) {
        line = line.trim();
        if (!line || line.startsWith(';')) continue;

        const loopMatch = line.match(/^(\w+)_LOOP\s*=\s*(\d+)/i);
        if (loopMatch) {
          song.loopOrderIndex = parseInt(loopMatch[2], 10);
          continue;
        }

        const labelMatch = line.match(/^(\w+)_pat_(\w+):/i);
        if (labelMatch) {
          if (curPatName && patData.length >= 48) {
            song.patterns[curPatName] = {
              mel: patData.slice(0, 16),
              bass: patData.slice(16, 32),
              drums: patData.slice(32, 48)
            };
          }
          curPatName = labelMatch[2];
          patData = [];
          if (!patNamesInOrder.includes(curPatName)) patNamesInOrder.push(curPatName);
          continue;
        }

        if (line.startsWith('.byte')) {
          const parts = line.replace(/^\.byte\s*/i, '').split(',').map(s => s.trim());
          for (let p of parts) {
            let val;
            if (p.startsWith('$')) val = parseInt(p.substr(1), 16);
            else if (p.startsWith('<') || p.startsWith('>')) continue;
            else val = parseInt(p, 10);

            if (curPatName) {
              patData.push(isNaN(val) ? 0 : val);
            } else if (!line.includes('_pat_')) {
              if (val === 255 || p === '$FF') break;
              patOrderIndices.push(val);
            }
          }
        }
      }

      if (curPatName && patData.length >= 48) {
        song.patterns[curPatName] = {
          mel: patData.slice(0, 16),
          bass: patData.slice(16, 32),
          drums: patData.slice(32, 48)
        };
      }

      song.order = patOrderIndices.map(idx => patNamesInOrder[idx] || patNamesInOrder[0] || 'A1');
      if (song.order.length === 0) {
        song.order = Object.keys(song.patterns);
      }

      return song;
    }

    exportJson(song) {
      return JSON.stringify(song, null, 2);
    }

    parseJson(jsonStr) {
      return JSON.parse(jsonStr);
    }
  }

  // ===========================================================================
  // Built-in Song Presets (Converted from tools/gen_music.py)
  // ===========================================================================
  function buildPresetSong(title, tempoFrames, loopIdx, barDefs, orderList, disableNoiseHat = false) {
    const patterns = {};
    for (let k of Object.keys(barDefs)) {
      const def = barDefs[k];
      const mel = def[0].split(/\s+/).map(nameToNoteIdx);
      const bass = def[1].split(/\s+/).map(nameToNoteIdx);
      const drums = def[2].split(/\s+/).map(t => (t === 'K' ? 1 : (t === 'S' ? 2 : 0)));
      const patObj = { mel, bass, drums };
      if (def[3]) {
        patObj.harm = def[3].split(/\s+/).map(nameToNoteIdx);
      } else {
        patObj.harm = new Array(16).fill(0);
      }
      patterns[k] = patObj;
    }
    return {
      title,
      tempoFrames,
      loopOrderIndex: loopIdx,
      order: orderList,
      patterns,
      disableNoiseHat
    };
  }

  function bassDriveStr(r1, r2) {
    r2 = r2 || r1;
    const pat = [0, 0, 12, 0, 0, 12, 0, 12];
    let res = [];
    [r1, r2].forEach(r => {
      let bIdx = nameToNoteIdx(r);
      pat.forEach(o => res.push(noteIdxToName(bIdx + o)));
    });
    return res.join(' ');
  }

  function bassGallopStr(r1, r2) {
    r2 = r2 || r1;
    const pat = [0, '.', 12, 0, 0, '.', 12, 0];
    let res = [];
    [r1, r2].forEach(r => {
      let bIdx = nameToNoteIdx(r);
      pat.forEach(o => res.push(o === '.' ? '.' : noteIdxToName(bIdx + o)));
    });
    return res.join(' ');
  }

  function bassBounceStr(r1, r2) {
    r2 = r2 || r1;
    const pat = [0, '.', 12, '.', 7, '.', 12, '.'];
    let res = [];
    [r1, r2].forEach(r => {
      let bIdx = nameToNoteIdx(r);
      pat.forEach(o => res.push(o === '.' ? '.' : noteIdxToName(bIdx + o)));
    });
    return res.join(' ');
  }

  const PRESETS = {
    stage1: buildPresetSong(
      'STAGE 1: LUNAR CATACOMB DRIVE',
      6, // 150 BPM
      2,
      {
        'I1': ['. . . . . . . . . . . . . . . .', bassDriveStr('D3'), 'K . . . . . . . K . . . . . . .'],
        'I2': ['. . . . . . . . A4 - C5 - D5 - E5 -', bassDriveStr('D3', 'A2'), 'K . . . S . . K K . S S S S S S'],
        'A1': ['F5 - - - - - E5 - D5 - - - A4 - - -', bassDriveStr('D3'), 'K . . . S . . K K . K . S . . .'],
        'A2': ['A#4 - - - C5 - D5 - F5 - - - E5 - D5 -', bassDriveStr('A#2'), 'K . . . S . . K K . K . S . . .'],
        'A3': ['E5 - - - - - D5 - C5 - - - G4 - - -', bassDriveStr('C3'), 'K . . . S . . K K . K . S . . .'],
        'A4': ['A4 - - - - - - - . . A4 - C5 - D5 -', bassDriveStr('D3'), 'K . . . S . . K K . K . S . . .'],
        'A5': ['F5 - - - - - G5 - A5 - - - F5 - D5 -', bassDriveStr('D3'), 'K . . . S . . K K . K . S . . .'],
        'A6': ['A#5 - - - A5 - G5 - F5 - - - G5 - A5 -', bassDriveStr('A#2'), 'K . . . S . . K K . K . S . . .'],
        'A7': ['G5 - F5 - E5 - D5 - E5 - - - C#5 - - -', bassDriveStr('G2', 'A2'), 'K . . . S . . K K . K . S . . .'],
        'A8': ['D5 - - - - - - - . . . . E5 - F5 -', bassDriveStr('A2'), 'K . . . S . . K K . S S S S S S'],
        'B1': ['G5 - - - - - - - A#5 - A5 - G5 - F5 -', bassGallopStr('G2'), 'K . . K S . . K . K K . S . K .'],
        'B2': ['E5 - - - - - - - C#5 - D5 - E5 - - -', bassGallopStr('A2'), 'K . . K S . . K . K K . S . K .'],
        'B3': ['F5 - - - - - E5 - D5 - - - F5 - A5 -', bassGallopStr('D3'), 'K . . K S . . K . K K . S . K .'],
        'B4': ['C6 - - - - - - - A5 - - - F5 - - -', bassGallopStr('F2'), 'K . . K S . . K . K K . S . K .'],
        'B5': ['A#5 - - - A5 - G5 - A5 - - - A#5 - - -', bassGallopStr('G2'), 'K . . K S . . K . K K . S . K .'],
        'B6': ['A5 - - - G5 - F5 - E5 - - - C#5 - E5 -', bassGallopStr('A2'), 'K . . K S . . K . K K . S . K .'],
        'B7': ['F5 - - - E5 - D5 - E5 - - - G5 - - -', bassDriveStr('A#2', 'C3'), 'K . . . S . . K K . K . S . . .'],
        'B8': ['A5 G5 F5 E5 D5 C#5 D5 E5 F5 E5 D5 C#5 C#5 - D5 -', bassDriveStr('A2'), 'K . . . S . . K K . S S S S S S']
      },
      ['I1', 'I2', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'A1', 'A2', 'A3', 'A4', 'A5', 'A6', 'A7', 'A8', 'B1', 'B2', 'B3', 'B4', 'B5', 'B6', 'B7', 'B8']
    ),

    boss: buildPresetSong(
      'BOSS: CRIMSON BATTLE GROUND',
      5, // 180 BPM
      2,
      {
        'BI1': ['E5 . G5 . B5 . E6 . D#6 . B5 . G5 . D#5 .', bassDriveStr('E3'), 'K . . . S . . . K . . . S . S .'],
        'BI2': ['E5 . G5 . B5 . E6 . D#6 - F#6 - G6 - A6 -', bassDriveStr('E3', 'B2'), 'K . K . S . K . S S S S S S S S'],
        'BA1': ['B5 - - - A5 - G5 - F#5 - G5 - E5 - - -', bassDriveStr('E3'), 'K . K . S . K . K . K . S . K .'],
        'BA2': ['C6 - - - B5 - A5 - G5 - - - A5 - B5 -', bassDriveStr('C3'), 'K . K . S . K . K K . K S . S .'],
        'BA3': ['A5 - - - G5 - F#5 - E5 - F#5 - D5 - - -', bassDriveStr('D3'), 'K . K . S . K . K . K . S . K .'],
        'BA4': ['E5 - - - - - - - . . B4 - D5 - E5 -', bassDriveStr('E3'), 'K . K . S . K . K K . K S . S .'],
        'BA5': ['B5 - - - C6 - D6 - B5 - - - G5 - - -', bassDriveStr('E3'), 'K . K . S . K . K . K . S . K .'],
        'BA6': ['C6 - - - D6 - E6 - C6 - - - A5 - - -', bassDriveStr('C3'), 'K . K . S . K . K K . K S . S .'],
        'BA7': ['D6 - - - C6 - B5 - A5 - - - B5 - C6 -', bassDriveStr('D3'), 'K . K . S . K . K . K . S . K .'],
        'BA8': ['B5 - - - - - - - . . F#5 - G5 - A5 -', bassDriveStr('B2'), 'K . K . S . K . S S S S S S S S'],
        'BB1': ['C6 - - - - - - - E6 - D6 - C6 - B5 -', bassDriveStr('A2'), 'K . K . S . K . K . K . S . K .'],
        'BB2': ['B5 - - - - - - - D6 - C6 - B5 - A5 -', bassDriveStr('B2'), 'K . K . S . K . K K . K S . S .'],
        'BB3': ['A5 - - - G5 - F#5 - G5 - - - A5 - - -', bassDriveStr('C3'), 'K . K . S . K . K . K . S . K .'],
        'BB4': ['F#5 - - - - - - - . . A5 - B5 - C6 -', bassDriveStr('D3'), 'K . K . S . K . K K . K S . S .'],
        'BB5': ['D6 - - - - - - - F#6 - E6 - D6 - C6 -', bassDriveStr('D3'), 'K . K . S . K . K . K . S . K .'],
        'BB6': ['E6 - - - - - - - B5 - - - G5 - - -', bassDriveStr('E3'), 'K . K . S . K . K K . K S . S .'],
        'BB7': ['C6 - - - B5 - A5 - B5 - - - D#6 - - -', bassDriveStr('C3', 'B2'), 'K . K . S . K . K . K . S . K .'],
        'BB8': ['E6 D#6 E6 F#6 G6 F#6 E6 D#6 B5 - D#6 - E6 - - -', bassDriveStr('B2'), 'K . K . S . K . S S S S S S S S']
      },
      ['BI1', 'BI2', 'BA1', 'BA2', 'BA3', 'BA4', 'BA5', 'BA6', 'BA7', 'BA8', 'BB1', 'BB2', 'BB3', 'BB4', 'BB5', 'BB6', 'BB7', 'BB8']
    ),

    title: buildPresetSong(
      'TITLE: SPACE MERCHANT - THE SYONIN',
      7, // 130 BPM
      2,
      {
        'TI1': ['C5 . F5 . A5 . C6 . A5 . F5 . C5 . . .', bassBounceStr('F3'), 'K . . . . . . . K . . . S . S .'],
        'TI2': ['D5 . F5 . A#5 . D6 . C6 - A#5 - A5 - G5 -', bassBounceStr('A#2', 'C3'), 'K . K . S . . K S S S S S S S S'],
        'TA1': ['A5 - F5 - C5 - F5 - A5 - A#5 - C6 - - -', bassBounceStr('F3'), 'K . . . S . . . K . K . S . . .'],
        'TA2': ['D6 - C6 - A#5 - A5 - G5 - - - - - - -', bassBounceStr('A#2', 'C3'), 'K . . . S . . . K . . . S . S .'],
        'TA3': ['A#5 - G5 - D5 - G5 - A#5 - C6 - D6 - - -', bassBounceStr('G2', 'C3'), 'K . . . S . . . K . K . S . . .'],
        'TA4': ['C6 - A#5 - A5 - G5 - F5 - - - - - - -', bassBounceStr('F3'), 'K . . . S . . . K . . . S . S .'],
        'TA5': ['A5 - F5 - C5 - F5 - A5 - A#5 - C6 - - -', bassBounceStr('F3'), 'K . . . S . . . K . K . S . . .'],
        'TA6': ['D6 - - - F6 - - - E6 - D6 - C6 - - -', bassBounceStr('A#2', 'F3'), 'K . . . S . . . K . . . S . S .'],
        'TA7': ['A#5 - A5 - G5 - F5 - E5 - F5 - G5 - - -', bassBounceStr('C3'), 'K . . . S . . . K . K . S . . .'],
        'TA8': ['F5 - - - - - - - . . C5 - D5 - E5 -', bassBounceStr('F3'), 'K . K . S . . K S S S S S S S S'],
        'TB1': ['F5 - D5 - A4 - D5 - F5 - - - D5 - - -', bassBounceStr('D3'), 'K . . . S . . . K . K . S . . .'],
        'TB2': ['G5 - E5 - A#4 - E5 - G5 - - - E5 - - -', bassBounceStr('G2'), 'K . . . S . . . K . K . S . . .'],
        'TB3': ['A5 - G5 - F5 - E5 - F5 - E5 - D5 - C#5 -', bassBounceStr('A2'), 'K . . . S . . . K . K . S . . .'],
        'TB4': ['D5 - - - - - - - . . F5 - G5 - A5 -', bassBounceStr('D3'), 'K . . . S . . . K . K . S . . .'],
        'TB5': ['A#5 - G5 - D5 - G5 - A#5 - - - - - - -', bassBounceStr('G2'), 'K . . . S . . . K . K . S . . .'],
        'TB6': ['C6 - A5 - F5 - A5 - C6 - - - - - - -', bassBounceStr('F3'), 'K . . . S . . . K . K . S . . .'],
        'TB7': ['D6 - C6 - A#5 - A5 - G5 - A5 - A#5 - G5 -', bassBounceStr('A#2', 'C3'), 'K . . . S . . . K . K . S . . .'],
        'TB8': ['C6 - - - - - - - . . G5 - A5 - A#5 -', bassBounceStr('C3'), 'K . K . S . . K S S S S S S S S']
      },
      ['TI1', 'TI2', 'TA1', 'TA2', 'TA3', 'TA4', 'TA5', 'TA6', 'TA7', 'TA8', 'TB1', 'TB2', 'TB3', 'TB4', 'TB5', 'TB6', 'TB7', 'TB8']
    ),

    gameover: buildPresetSong(
      'GAME OVER: REST IN PEACE',
      12, // 75 BPM
      0,
      {
        'GO1': ['. . . . . . . . G#4 - - - A#4 - - -', 'F2 - - - C3 - - - F2 - - - C3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO2': ['C5 - - - - - - - D5 - - - - - - -', 'F2 - - - C3 - - - F2 - - - C3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO3': ['C5 - - - A#4 - - - G#4 - - - F4 - - -', 'F2 - - - C3 - - - F2 - - - C3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO4': ['D#4 - - - - - - - F4 - - - G4 - - -', 'D#2 - - - A#2 - - - D#2 - - - A#2 - - -', '. . . . . . . . . . . . . . . .'],
        'GO5': ['G#4 - - - - - - - - - - - - - - -', 'G#2 - - - D#3 - - - G#2 - - - D#3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO6': ['. . . . . . . . C5 - - - D#5 - - -', 'C3 - - - G3 - - - C3 - - - G3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO7': ['F5 - - - - - - - D#5 - - - D5 - - -', 'C#3 - - - G#3 - - - A#2 - - - F3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO8': ['C5 - - - A#4 - - - A#4 - - - - - - -', 'C3 - - - G3 - - - C3 - - - G3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO9': ['. . . . . . . . G#4 - - - A#4 - - -', 'F2 - - - C3 - - - F2 - - - C3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO10': ['C5 - - - - - - - D5 - - - - - - -', 'F2 - - - C3 - - - F2 - - - C3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO11': ['C5 - - - A#4 - - - G#4 - - - F4 - - -', 'F2 - - - C3 - - - F2 - - - C3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO12': ['D#4 - - - - - - - F4 - - - G4 - - -', 'D#2 - - - A#2 - - - D#2 - - - A#2 - - -', '. . . . . . . . . . . . . . . .'],
        'GO13': ['F4 - - - - - - - - - - - - - - -', 'F2 - - - C3 - - - F3 - - - C3 - - -', '. . . . . . . . . . . . . . . .'],
        'GO14': ['. . . . . . . . . . . . . . . .', 'F2 - - - - - - - . . . . . . . .', '. . . . . . . . . . . . . . . .']
      },
      ['GO1', 'GO2', 'GO3', 'GO4', 'GO5', 'GO6', 'GO7', 'GO8', 'GO9', 'GO10', 'GO11', 'GO12', 'GO13', 'GO14'],
      true // Silence noise hat in Game Over
    ),
    tears_of_sylph: buildPresetSong(
      'GAME OVER: TEARS OF SYLPH (Ys風アレンジ)',
      13, // 69.3 BPM
      0,
      {
        'Y1':  ['A4 - - - D5 - - - F5 - - - E5 - - -', 'D2 - - - A2 - - - D3 - - - F3 - - -', '. . . . . . . . . . . . . . . .', 'D4 - - - F4 - - - A4 - - - D5 - - -'],
        'Y2':  ['D5 - - - - - - - C#5 - - - D5 - - -', 'C#2 - - - A2 - - - E3 - - - A3 - - -', '. . . . . . . . . . . . . . . .', 'F4 - - - A4 - - - E4 - - - F4 - - -'],
        'Y3':  ['E5 - - - - - F5 - D5 - - - - - - -', 'A#2 - - - F3 - - - A#3 - - - D4 - - -', '. . . . . . . . . . . . . . . .', 'G4 - - - - - A4 - F4 - - - A4 - - -'],
        'Y4':  ['C#5 - - - - - - - - - - - - - - -', 'A2 - - - E3 - - - A3 - - - C#4 - - -', '. . . . . . . . . . . . . . . .', 'E4 - - - - - - - A4 - - - C#5 - - -'],
        'Y5':  ['A4 - - - D5 - - - F5 - - - G5 - - -', 'D2 - - - A2 - - - D3 - - - F3 - - -', '. . . . . . . . . . . . . . . .', 'D4 - - - F4 - - - A4 - - - B4 - - -'],
        'Y6':  ['A5 - - - - - - - G5 - - - F5 - - -', 'G2 - - - D3 - - - G3 - - - A#3 - - -', '. . . . . . . . . . . . . . . .', 'C#5 - - - - - - - E5 - - - D5 - - -'],
        'Y7':  ['E5 - - - - - F5 - E5 - - - D5 - - -', 'A2 - - - E3 - - - G3 - - - A3 - - -', '. . . . . . . . . . . . . . . .', 'C#5 - - - - - D5 - C#5 - - - A4 - - -'],
        'Y8':  ['D5 - - - - - - - - - - - - - - -', 'D2 - - - A2 - - - D3 - - - - - - -', '. . . . . . . . . . . . . . . .', 'F4 - - - A4 - - - D5 - - - F5 - - -'],
        'Y9':  ['F5 - - - G5 - - - A5 - - - - - - -', 'F2 - - - C3 - - - F3 - - - A3 - - -', '. . . . . . . . . . . . . . . .', 'D5 - - - E5 - - - F5 - - - - - - -'],
        'Y10': ['A#5 - - - - - - - A5 - - - G5 - - -', 'G2 - - - D3 - - - G3 - - - A#3 - - -', '. . . . . . . . . . . . . . . .', 'G5 - - - - - - - F5 - - - E5 - - -'],
        'Y11': ['A5 - - - - - - - F5 - - - D5 - - -', 'D2 - - - A2 - - - D3 - - - F3 - - -', '. . . . . . . . . . . . . . . .', 'F5 - - - - - - - D5 - - - A4 - - -'],
        'Y12': ['E5 - - - - - - - - - - - - - - -', 'A2 - - - E3 - - - A3 - - - C#4 - - -', '. . . . . . . . . . . . . . . .', 'C#5 - - - - - - - - - - - - - - -'],
        'Y13': ['F5 - - - E5 - - - D5 - - - C#5 - - -', 'A#2 - - - F3 - - - A2 - - - E3 - - -', '. . . . . . . . . . . . . . . .', 'D5 - - - C#5 - - - A#4 - - - A4 - - -'],
        'Y14': ['D5 - - - - - - - - - - - - - - -', 'D2 - - - A2 - - - D3 - - - - - - -', '. . . . . . . . . . . . . . . .', 'F4 - - - A4 - - - D5 - - - - - - -'],
        'Y15': ['. . . . . . . . . . . . . . . .', 'D2 - - - - - - - . . . . . . . .', '. . . . . . . . . . . . . . . .', '. . . . . . . . . . . . . . . .']
      },
      ['Y1', 'Y2', 'Y3', 'Y4', 'Y5', 'Y6', 'Y7', 'Y8', 'Y9', 'Y10', 'Y11', 'Y12', 'Y13', 'Y14', 'Y15'],
      true
    )
  };

  // Export to global
  NesAudioPlayer.PRESETS = PRESETS;
  NesAudioPlayer.noteIdxToName = noteIdxToName;
  NesAudioPlayer.nameToNoteIdx = nameToNoteIdx;
  NesAudioPlayer.noteIdxToFreq = noteIdxToFreq;
  NesAudioPlayer.HOLD = HOLD;
  NesAudioPlayer.REST = REST;

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = NesAudioPlayer;
  } else {
    global.NesAudioPlayer = NesAudioPlayer;
  }
})(typeof window !== 'undefined' ? window : this);
