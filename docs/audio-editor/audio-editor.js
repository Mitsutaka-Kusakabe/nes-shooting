/**
 * audio-editor.js
 * Frontend controller for MOJAxMOJA WARS Web Music Editor
 */

(function () {
  'use strict';

  const player = new NesAudioPlayer();

  // Range of notes for piano roll (A1: idx 1 to C7: idx 64 - Full NES APU Range)
  const MIN_NOTE_IDX = 1;   // A1 (MIDI 33)
  const MAX_NOTE_IDX = 64;  // C7 (MIDI 96)
  const TOTAL_KEYS = MAX_NOTE_IDX - MIN_NOTE_IDX + 1; // 64 keys
  const KEY_HEIGHT = 18;
  const STEP_WIDTH = 48;
  const TOTAL_STEPS = 16;

  // Editor State
  let curChannel = 'pulse1'; // 'pulse1' | 'pulse2' | 'triangle' | 'dmc'
  let curPattern = 'A1';
  let curOrderIdx = 0;
  let activePlayheadStep = -1;
  let isDragging = false;
  let dragStartStep = -1;
  let dragNoteIdx = -1;

  // Active Song Project
  let song = JSON.parse(JSON.stringify(NesAudioPlayer.PRESETS.stage1));

  // DOM Elements
  const cv = document.getElementById('grid-canvas');
  const cx = cv.getContext('2d');
  const pianoKeysEl = document.getElementById('piano-keys');
  const rollContainer = document.getElementById('roll-container');
  const drumView = document.getElementById('drum-view');
  const posDisplay = document.getElementById('position-display');
  const patternSelect = document.getElementById('pattern-select');
  const curPatBadge = document.getElementById('cur-pat-name-badge');
  const orderContainer = document.getElementById('order-slots-container');
  const presetSelect = document.getElementById('preset-select');
  const tempoSelect = document.getElementById('tempo-select');
  const masterVol = document.getElementById('master-vol');

  // Baseline Song Project (tracks saved/unmodified reference for dirty marks)
  let baselineSong = JSON.parse(JSON.stringify(song));

  function resetBaseline() {
    baselineSong = JSON.parse(JSON.stringify(song));
    syncUI();
  }

  function isPatternDirty(patKey) {
    if (!baselineSong || !baselineSong.patterns) return false;
    const basePat = baselineSong.patterns[patKey];
    const curPat = song.patterns[patKey];
    if (!basePat && curPat) return true;
    if (basePat && !curPat) return true;
    if (!basePat && !curPat) return false;
    return JSON.stringify(basePat) !== JSON.stringify(curPat);
  }

  function isStepDirty(patKey, chKey, step) {
    if (!baselineSong || !baselineSong.patterns) return false;
    const basePat = baselineSong.patterns[patKey];
    const curPat = song.patterns[patKey];
    if (!basePat || !curPat) return true;
    let baseRow = null;
    let curRow = null;
    if (chKey === 'pulse1') { baseRow = basePat.mel; curRow = curPat.mel; }
    else if (chKey === 'pulse2') { baseRow = basePat.harm; curRow = curPat.harm; }
    else if (chKey === 'triangle') { baseRow = basePat.bass; curRow = curPat.bass; }
    else if (chKey === 'dmc') { baseRow = basePat.drums; curRow = curPat.drums; }
    const baseVal = (baseRow && baseRow[step]) || 0;
    const curVal = (curRow && curRow[step]) || 0;
    return baseVal !== curVal;
  }

  function isSongDirty() {
    return JSON.stringify(song) !== JSON.stringify(baselineSong);
  }

  function updatePositionDisplay(oIdx = curOrderIdx, step = activePlayheadStep) {
    const isCurDirty = isPatternDirty(curPattern) || (song.order && isPatternDirty(song.order[oIdx]));
    const barNum = (oIdx >= 0 ? oIdx : 0) + 1;
    const stepNum = (step >= 0 ? step : 0) + 1;
    const barStr = `BAR ${String(barNum).padStart(2, '0')}${isCurDirty ? '*' : ''}`;
    const stepStr = `STEP ${String(stepNum).padStart(2, '0')}`;
    const dirtyBadge = isSongDirty() ? ' <span class="dirty-badge" title="未保存の変更があります">● [変更あり]</span>' : '';
    posDisplay.innerHTML = `${barStr} : ${stepStr}${dirtyBadge}`;

    const patDirty = isPatternDirty(curPattern);
    curPatBadge.innerHTML = `${curPattern}${patDirty ? ' <span style="color:#ff9800;font-size:11px;">● 未保存</span>' : ''}`;
  }

  // ===========================================================================
  // History Management (Undo / Redo)
  // ===========================================================================
  const MAX_HISTORY = 60;
  const undoStack = [];
  const redoStack = [];

  function recordSnapshot() {
    return {
      song: JSON.parse(JSON.stringify(song)),
      curPattern,
      curChannel,
      curOrderIdx
    };
  }

  function pushUndo() {
    undoStack.push(recordSnapshot());
    if (undoStack.length > MAX_HISTORY) {
      undoStack.shift();
    }
    redoStack.length = 0;
    updateUndoRedoButtons();
  }

  function undo() {
    if (undoStack.length === 0) return;
    redoStack.push(recordSnapshot());
    const prev = undoStack.pop();
    applySnapshot(prev);
    updateUndoRedoButtons();
  }

  function redo() {
    if (redoStack.length === 0) return;
    undoStack.push(recordSnapshot());
    const next = redoStack.pop();
    applySnapshot(next);
    updateUndoRedoButtons();
  }

  function applySnapshot(snap) {
    song = snap.song;
    curPattern = snap.curPattern;
    curChannel = snap.curChannel;
    curOrderIdx = snap.curOrderIdx;
    syncUI();
  }

  function updateUndoRedoButtons() {
    const uBtn = document.getElementById('btn-undo');
    const rBtn = document.getElementById('btn-redo');
    if (uBtn) uBtn.disabled = undoStack.length === 0;
    if (rBtn) rBtn.disabled = redoStack.length === 0;
  }

  // ===========================================================================
  // Initialization
  // ===========================================================================
  function init() {
    setupCanvas();
    buildPianoKeys();
    buildDrumView();
    syncUI();
    bindEvents();
    bindKeyboardKeys();

    // Scroll to center octave (around C4)
    setTimeout(() => {
      const c4Offset = (MAX_NOTE_IDX - 28) * KEY_HEIGHT - 120;
      rollContainer.scrollTop = Math.max(0, c4Offset);
    }, 50);
  }

  function setupCanvas() {
    cv.width = STEP_WIDTH * TOTAL_STEPS;
    cv.height = TOTAL_KEYS * KEY_HEIGHT;
    cv.style.width = `${cv.width}px`;
    cv.style.height = `${cv.height}px`;
  }

  function buildPianoKeys() {
    pianoKeysEl.innerHTML = '';
    pianoKeysEl.style.height = `${TOTAL_KEYS * KEY_HEIGHT}px`;

    for (let idx = MAX_NOTE_IDX; idx >= MIN_NOTE_IDX; idx--) {
      const name = NesAudioPlayer.noteIdxToName(idx);
      const isBlack = name.includes('#');
      const key = document.createElement('div');
      key.className = `piano-key ${isBlack ? 'black' : 'white'}`;
      key.dataset.noteIdx = idx;
      key.textContent = name;

      // Pointerdown: instant note start on touch/mouse
      key.addEventListener('pointerdown', (e) => {
        e.preventDefault();
        player.initAudio();
        setActivePianoKey(idx);
        player.startNote(curChannel, idx);
      });

      // Pointerenter with button held: glissando / sliding across keys
      key.addEventListener('pointerenter', (e) => {
        if (e.buttons === 1) {
          e.preventDefault();
          setActivePianoKey(idx);
          player.startNote(curChannel, idx);
        }
      });

      key.addEventListener('pointerup', (e) => {
        e.preventDefault();
        setActivePianoKey(null);
        player.stopNote(curChannel);
      });

      key.addEventListener('pointerleave', () => {
        if (key.classList.contains('active')) {
          setActivePianoKey(null);
          player.stopNote(curChannel);
        }
      });

      pianoKeysEl.appendChild(key);
    }
  }

  function setActivePianoKey(noteIdx) {
    document.querySelectorAll('.piano-key.active').forEach(k => k.classList.remove('active'));
    if (noteIdx) {
      const target = document.querySelector(`.piano-key[data-note-idx="${noteIdx}"]`);
      if (target) target.classList.add('active');
    }
  }

  function buildDrumView() {
    const kickSteps = document.getElementById('kick-steps');
    const snareSteps = document.getElementById('snare-steps');
    kickSteps.innerHTML = '';
    snareSteps.innerHTML = '';

    for (let s = 0; s < 16; s++) {
      const kStep = document.createElement('div');
      kStep.className = 'drum-step';
      kStep.dataset.step = s;
      kStep.textContent = s + 1;
      kStep.addEventListener('click', () => toggleDrum(s, 1));
      kickSteps.appendChild(kStep);

      const sStep = document.createElement('div');
      sStep.className = 'drum-step';
      sStep.dataset.step = s;
      sStep.textContent = s + 1;
      sStep.addEventListener('click', () => toggleDrum(s, 2));
      snareSteps.appendChild(sStep);
    }
  }

  // ===========================================================================
  // UI Sync & Rendering
  // ===========================================================================
  function syncUI() {
    // 1. Channel tab selections
    document.querySelectorAll('.channel-tab').forEach(tab => {
      tab.classList.toggle('selected', tab.dataset.ch === curChannel);
    });

    if (curChannel === 'dmc') {
      rollContainer.style.display = 'none';
      drumView.style.display = 'flex';
      renderDrumView();
    } else {
      rollContainer.style.display = 'flex';
      drumView.style.display = 'none';
      renderGrid();
    }

    // 2. Pattern Select
    patternSelect.innerHTML = '';
    const patKeys = Object.keys(song.patterns || {});
    if (!song.patterns[curPattern] && patKeys.length > 0) {
      curPattern = patKeys[0];
    }
    const patDirty = isPatternDirty(curPattern);
    curPatBadge.innerHTML = `${curPattern}${patDirty ? ' <span style="color:#ff9800;font-size:11px;">● 未保存</span>' : ''}`;

    patKeys.forEach(k => {
      const opt = document.createElement('option');
      opt.value = k;
      opt.textContent = `小節 ${k}${isPatternDirty(k) ? ' ●' : ''}`;
      if (k === curPattern) opt.selected = true;
      patternSelect.appendChild(opt);
    });

    // 3. Song Order Bar
    renderOrderBar();

    // 4. Update Header Position Display
    updatePositionDisplay();

    // 5. Tempo & Controls
    const tf = song.tempoFrames || 6;
    let opt = Array.from(tempoSelect.options).find(o => parseInt(o.value, 10) === tf);
    if (!opt) {
      opt = document.createElement('option');
      opt.value = tf;
      const bpm = Math.round((3600 / tf) / 4);
      opt.textContent = `${bpm} BPM (${tf} f/step)`;
      tempoSelect.appendChild(opt);
    }
    tempoSelect.value = String(tf);

    // 6. Auto scroll to active note range if not in drum view
    if (curChannel !== 'dmc') {
      setTimeout(() => scrollToNotes(), 10);
    }
  }

  function scrollToNotes() {
    const pat = song.patterns[curPattern];
    if (!pat) return;
    let rowData = (curChannel === 'pulse1') ? pat.mel : ((curChannel === 'pulse2') ? pat.harm : pat.bass);
    if (!rowData) return;

    let sum = 0, count = 0;
    rowData.forEach(v => {
      if (v && v !== NesAudioPlayer.HOLD && v !== NesAudioPlayer.REST) {
        sum += v;
        count++;
      }
    });

    let targetIdx = 37; // Default A4
    if (count > 0) {
      targetIdx = Math.round(sum / count);
    } else if (curChannel === 'triangle') {
      targetIdx = 18; // D3 for bass
    }

    const containerH = rollContainer.clientHeight || 400;
    const targetY = (MAX_NOTE_IDX - targetIdx) * KEY_HEIGHT - (containerH / 2) + 20;
    rollContainer.scrollTop = Math.max(0, targetY);
  }

  function renderOrderBar() {
    orderContainer.innerHTML = '';
    const order = song.order || [];
    const loopIdx = song.loopOrderIndex || 0;

    const orderLabel = document.getElementById('order-label');
    if (orderLabel && order.length > 0) {
      const loopStartName = order[loopIdx] || order[0];
      const loopEndName = order[order.length - 1];
      orderLabel.innerHTML = `小節オーダー: <span style="font-size:10px; color:#aaccff; font-weight:normal;">(ループ: <b>${loopIdx + 1}:${loopStartName}</b> 🔁 <b>${order.length}:${loopEndName}</b>)</span>`;
    }

    order.forEach((k, oIdx) => {
      const slot = document.createElement('div');
      slot.className = `order-slot ${oIdx === curOrderIdx ? 'active' : ''}`;
      const isDirty = isPatternDirty(k);
      if (isDirty) {
        slot.classList.add('dirty');
      }
      
      if (oIdx === loopIdx) {
        slot.classList.add('loop-start');
        slot.title = `【ループ開始 |:】末尾まで演奏後、ここ (${oIdx + 1}:${k}) に戻ります`;
      }
      if (oIdx === order.length - 1) {
        slot.classList.add('loop-end');
        slot.title = `【ループ終端 :|】演奏終了後、${loopIdx + 1}:${order[loopIdx]} へループ再開します`;
      }

      const txt = document.createElement('span');
      txt.textContent = `${oIdx + 1}:${k}`;
      slot.appendChild(txt);

      if (isDirty) {
        const dot = document.createElement('span');
        dot.className = 'dirty-dot';
        dot.textContent = ' ●';
        dot.title = `小節パターン ${k} は保存後に編集されています`;
        slot.appendChild(dot);
      }

      slot.addEventListener('click', () => {
        curOrderIdx = oIdx;
        curPattern = k;
        player.seek(curOrderIdx, 0);
        syncUI();
      });

      if (order.length > 1) {
        const delBtn = document.createElement('span');
        delBtn.className = 'remove-btn';
        delBtn.textContent = '✕';
        delBtn.title = 'この小節を削除';
        delBtn.addEventListener('click', (e) => {
          e.stopPropagation();
          pushUndo();
          order.splice(oIdx, 1);
          if (curOrderIdx >= order.length) curOrderIdx = order.length - 1;
          curPattern = order[curOrderIdx];
          syncUI();
        });
        slot.appendChild(delBtn);
      }

      orderContainer.appendChild(slot);
    });
  }

  function renderGrid() {
    cx.clearRect(0, 0, cv.width, cv.height);

    const pat = song.patterns[curPattern];
    if (!pat) return;

    let rowData = null;
    let trackColor = '#ff5722';
    if (curChannel === 'pulse1') {
      rowData = pat.mel;
      trackColor = '#ff5722';
    } else if (curChannel === 'pulse2') {
      rowData = pat.harm || (pat.harm = new Array(16).fill(0));
      trackColor = '#ff9800';
    } else if (curChannel === 'triangle') {
      rowData = pat.bass;
      trackColor = '#4caf50';
    }

    // 1. Grid Background & Pitch Rows
    for (let idx = MAX_NOTE_IDX; idx >= MIN_NOTE_IDX; idx--) {
      const y = (MAX_NOTE_IDX - idx) * KEY_HEIGHT;
      const name = NesAudioPlayer.noteIdxToName(idx);
      const isBlack = name.includes('#');

      cx.fillStyle = isBlack ? '#11141c' : '#181e29';
      cx.fillRect(0, y, cv.width, KEY_HEIGHT);

      cx.strokeStyle = '#252e3e';
      cx.beginPath();
      cx.moveTo(0, y + KEY_HEIGHT);
      cx.lineTo(cv.width, y + KEY_HEIGHT);
      cx.stroke();
    }

    // 2. Vertical Step Grid Lines (16 steps)
    for (let s = 0; s <= TOTAL_STEPS; s++) {
      const x = s * STEP_WIDTH;
      cx.strokeStyle = (s % 4 === 0) ? '#4a5d7c' : '#252e3e';
      cx.lineWidth = (s % 4 === 0) ? 2 : 1;
      cx.beginPath();
      cx.moveTo(x, 0);
      cx.lineTo(x, cv.height);
      cx.stroke();
    }
    cx.lineWidth = 1;

    // 3. Render Notes for current track
    if (rowData) {
      let activeNoteIdx = 0;
      let noteStartStep = 0;

      for (let s = 0; s < 16; s++) {
        const val = rowData[s];
        const stepDirty = isStepDirty(curPattern, curChannel, s);
        if (val && val !== NesAudioPlayer.HOLD && val !== NesAudioPlayer.REST) {
          activeNoteIdx = val;
          noteStartStep = s;
          drawNoteBlock(noteStartStep, activeNoteIdx, 1, trackColor, false, stepDirty);
        } else if (val === NesAudioPlayer.HOLD && activeNoteIdx) {
          drawNoteBlock(s, activeNoteIdx, 1, trackColor, true, stepDirty);
        } else {
          activeNoteIdx = 0;
        }
      }
    }

    // 4. Playhead cursor (if playing on current bar)
    if (activePlayheadStep >= 0 && activePlayheadStep < 16 && orderIsCurrent()) {
      const px = activePlayheadStep * STEP_WIDTH;
      cx.fillStyle = 'rgba(255, 215, 0, 0.25)';
      cx.fillRect(px, 0, STEP_WIDTH, cv.height);

      cx.strokeStyle = '#ffd700';
      cx.lineWidth = 2;
      cx.beginPath();
      cx.moveTo(px, 0);
      cx.lineTo(px, cv.height);
      cx.stroke();
      cx.lineWidth = 1;
    }
  }

  function orderIsCurrent() {
    const order = song.order || [];
    return order[curOrderIdx] === curPattern;
  }

  function drawNoteBlock(step, noteIdx, lenSteps, color, isExtension, isDirty) {
    if (noteIdx < MIN_NOTE_IDX || noteIdx > MAX_NOTE_IDX) return;
    const y = (MAX_NOTE_IDX - noteIdx) * KEY_HEIGHT + 2;
    const x = step * STEP_WIDTH + (isExtension ? 0 : 2);
    const w = STEP_WIDTH * lenSteps - (isExtension ? 2 : 4);
    const h = KEY_HEIGHT - 4;

    cx.fillStyle = color;
    cx.fillRect(x, y, w, h);

    if (!isExtension) {
      cx.fillStyle = '#ffffff';
      cx.font = 'bold 10px monospace';
      cx.fillText(NesAudioPlayer.noteIdxToName(noteIdx), x + 4, y + 12);
    }

    if (isDirty) {
      // Draw dirty indicator dot (orange circle) on note block
      cx.fillStyle = '#ff9800';
      cx.beginPath();
      cx.arc(x + w - 5, y + 5, 3, 0, Math.PI * 2);
      cx.fill();
      cx.strokeStyle = '#221100';
      cx.lineWidth = 1;
      cx.stroke();
    }
  }

  function renderDrumView() {
    const pat = song.patterns[curPattern];
    if (!pat) return;
    const drums = pat.drums || (pat.drums = new Array(16).fill(0));

    const kickSteps = document.querySelectorAll('#kick-steps .drum-step');
    const snareSteps = document.querySelectorAll('#snare-steps .drum-step');

    drums.forEach((v, s) => {
      kickSteps[s].classList.toggle('active-kick', v === 1);
      snareSteps[s].classList.toggle('active-snare', v === 2);
      const isDirty = isStepDirty(curPattern, 'dmc', s);
      kickSteps[s].classList.toggle('step-dirty', isDirty);
      snareSteps[s].classList.toggle('step-dirty', isDirty);
    });
  }

  function toggleDrum(step, drumType) {
    const pat = song.patterns[curPattern];
    if (!pat) return;
    const drums = pat.drums || (pat.drums = new Array(16).fill(0));

    player.initAudio();
    pushUndo();
    if (drums[step] === drumType) {
      drums[step] = 0;
    } else {
      drums[step] = drumType;
      player.previewNote('dmc', drumType, 0.25);
    }
    renderDrumView();
    renderOrderBar();
    updatePositionDisplay();
  }

  // ===========================================================================
  // Mouse & Editing Handlers on Piano Roll
  // ===========================================================================
  cv.addEventListener('pointerdown', (e) => {
    if (e.button !== 0 && e.button !== 2) return;
    player.initAudio();
    const rect = cv.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const y = e.clientY - rect.top;

    const step = Math.floor(x / STEP_WIDTH);
    const keyRow = Math.floor(y / KEY_HEIGHT);
    const noteIdx = MAX_NOTE_IDX - keyRow;

    if (step < 0 || step >= 16 || noteIdx < MIN_NOTE_IDX || noteIdx > MAX_NOTE_IDX) return;

    const pat = song.patterns[curPattern];
    let rowData = (curChannel === 'pulse1') ? pat.mel : ((curChannel === 'pulse2') ? pat.harm : pat.bass);

    if (e.button === 2) {
      // Right click: Erase note
      e.preventDefault();
      if (rowData[step] !== NesAudioPlayer.REST) {
        pushUndo();
        rowData[step] = NesAudioPlayer.REST;
        setActivePianoKey(null);
        renderGrid();
        renderOrderBar();
        updatePositionDisplay();
      }
      return;
    }

    // Left click: Play note sound & toggle or place note!
    player.startNote(curChannel, noteIdx);
    setActivePianoKey(noteIdx);

    if (rowData[step] === noteIdx) {
      // Clicking same note auditions it; double click or right click erases
      // Keep note active
    } else {
      pushUndo();
      rowData[step] = noteIdx;
      isDragging = true;
      dragStartStep = step;
      dragNoteIdx = noteIdx;
      renderOrderBar();
      updatePositionDisplay();
    }
    renderGrid();
  });

  cv.addEventListener('pointermove', (e) => {
    if (!isDragging) return;
    const rect = cv.getBoundingClientRect();
    const x = e.clientX - rect.left;
    const step = Math.floor(x / STEP_WIDTH);
    if (step <= dragStartStep || step >= 16) return;

    const pat = song.patterns[curPattern];
    let rowData = (curChannel === 'pulse1') ? pat.mel : ((curChannel === 'pulse2') ? pat.harm : pat.bass);

    for (let s = dragStartStep + 1; s <= step; s++) {
      rowData[s] = NesAudioPlayer.HOLD;
    }
    renderGrid();
  });

  window.addEventListener('pointerup', () => {
    if (isDragging) {
      isDragging = false;
      renderOrderBar();
      updatePositionDisplay();
    }
    player.stopNote(curChannel);
    setActivePianoKey(null);
  });

  cv.addEventListener('contextmenu', (e) => e.preventDefault());

  // ===========================================================================
  // Computer Keyboard Musical Input (A, S, D, F, G, H, J, K...)
  // ===========================================================================
  function bindKeyboardKeys() {
    // Mapping from computer keys to Note indices around C4 (idx 28)
    const KEY_NOTE_MAP = {
      'KeyZ': 16, // C3
      'KeyS': 17, // C#3
      'KeyX': 18, // D3
      'KeyD': 19, // D#3
      'KeyC': 20, // E3
      'KeyV': 21, // F3
      'KeyG': 22, // F#3
      'KeyB': 23, // G3
      'KeyH': 24, // G#3
      'KeyN': 25, // A3
      'KeyJ': 26, // A#3
      'KeyM': 27, // B3
      'KeyQ': 28, // C4
      'Digit2': 29, // C#4
      'KeyW': 30, // D4
      'Digit3': 31, // D#4
      'KeyE': 32, // E4
      'KeyR': 33, // F4
      'Digit5': 34, // F#4
      'KeyT': 35, // G4
      'Digit6': 36, // G#4
      'KeyY': 37, // A4
      'Digit7': 38, // A#4
      'KeyU': 39, // B4
      'KeyI': 40  // C5
    };

    window.addEventListener('keydown', (e) => {
      if (e.target.tagName === 'INPUT' || e.target.tagName === 'TEXTAREA' || e.target.tagName === 'SELECT') return;

      // Undo / Redo Shortcuts: Ctrl+Z / Cmd+Z, Ctrl+Y / Cmd+Y / Ctrl+Shift+Z
      if ((e.ctrlKey || e.metaKey) && (e.key === 'z' || e.key === 'Z')) {
        e.preventDefault();
        if (e.shiftKey) {
          redo();
        } else {
          undo();
        }
        return;
      }
      if ((e.ctrlKey || e.metaKey) && (e.key === 'y' || e.key === 'Y')) {
        e.preventDefault();
        redo();
        return;
      }

      const noteIdx = KEY_NOTE_MAP[e.code];
      if (noteIdx && !e.repeat) {
        player.initAudio();
        setActivePianoKey(noteIdx);
        player.startNote(curChannel, noteIdx);
      }
    });

    window.addEventListener('keyup', (e) => {
      const noteIdx = KEY_NOTE_MAP[e.code];
      if (noteIdx) {
        player.stopNote(curChannel);
        setActivePianoKey(null);
      }
    });
  }

  // ===========================================================================
  // Sequencer & Transport Callbacks
  // ===========================================================================
  player.onStep = (oIdx, step, totalStep, audioTime) => {
    curOrderIdx = oIdx;
    activePlayheadStep = step;
    updatePositionDisplay(oIdx, step);

    const order = song.order || [];
    if (order[oIdx] && order[oIdx] !== curPattern) {
      curPattern = order[oIdx];
      patternSelect.value = curPattern;
      renderOrderBar();
      updatePositionDisplay(oIdx, step);
    }

    if (curChannel === 'dmc') {
      const kSteps = document.querySelectorAll('#kick-steps .drum-step');
      const sSteps = document.querySelectorAll('#snare-steps .drum-step');
      kSteps.forEach((el, idx) => el.style.borderColor = idx === step ? '#ffd700' : '');
      sSteps.forEach((el, idx) => el.style.borderColor = idx === step ? '#ffd700' : '');
    } else {
      renderGrid();
    }
  };

  player.onStop = () => {
    activePlayheadStep = -1;
    document.getElementById('btn-play').textContent = '▶ 再生';
    renderGrid();
    updatePositionDisplay();
  };

  // ===========================================================================
  // Event Bindings
  // ===========================================================================
  function bindEvents() {
    // Play / Pause / Stop
    document.getElementById('btn-play').addEventListener('click', () => {
      player.initAudio();
      if (player.isPlaying && !player.isPaused) {
        player.pause();
        document.getElementById('btn-play').textContent = '▶ 再開';
      } else if (player.isPaused) {
        player.resume();
        document.getElementById('btn-play').textContent = '⏸ 一時停止';
      } else {
        player.playSong(song, curOrderIdx, 0);
        document.getElementById('btn-play').textContent = '⏸ 一時停止';
      }
    });

    document.getElementById('btn-stop').addEventListener('click', () => {
      player.stop();
    });

    document.getElementById('btn-rewind').addEventListener('click', () => {
      curOrderIdx = 0;
      curPattern = (song.order && song.order[0]) || 'A1';
      player.seek(0, 0);
      syncUI();
    });

    // Undo / Redo buttons
    document.getElementById('btn-undo').addEventListener('click', () => {
      undo();
    });

    document.getElementById('btn-redo').addEventListener('click', () => {
      redo();
    });

    // Preset selection
    presetSelect.addEventListener('change', (e) => {
      const key = e.target.value;
      if (NesAudioPlayer.PRESETS[key]) {
        player.stop();
        song = JSON.parse(JSON.stringify(NesAudioPlayer.PRESETS[key]));
        curOrderIdx = 0;
        curPattern = (song.order && song.order[0]) || Object.keys(song.patterns)[0];
        undoStack.length = 0;
        redoStack.length = 0;
        updateUndoRedoButtons();
        resetBaseline();
      }
    });

    // Tempo & Volume
    tempoSelect.addEventListener('change', (e) => {
      pushUndo();
      song.tempoFrames = parseInt(e.target.value, 10);
      updatePositionDisplay();
    });

    masterVol.addEventListener('input', (e) => {
      player.setMasterVolume(e.target.value / 100.0);
    });

    // Loop point
    document.getElementById('btn-set-loop').addEventListener('click', () => {
      pushUndo();
      song.loopOrderIndex = curOrderIdx;
      alert(`小節 ${curOrderIdx + 1} (${curPattern}) をループ再開ポイントに設定しました！`);
      renderOrderBar();
      updatePositionDisplay();
    });

    // Add Order Slot
    document.getElementById('btn-add-order-slot').addEventListener('click', () => {
      pushUndo();
      song.order.push(curPattern);
      renderOrderBar();
      updatePositionDisplay();
    });

    // Channel selection tabs
    document.querySelectorAll('.channel-tab').forEach(tab => {
      tab.addEventListener('click', (e) => {
        if (e.target.closest('.toggle-chip') || e.target.closest('select') || e.target.closest('input')) return;
        curChannel = tab.dataset.ch;
        syncUI();
      });
    });

    // Channel Duty & Vol Controls
    document.querySelectorAll('.duty-sel').forEach(sel => {
      sel.addEventListener('change', (e) => {
        const ch = e.target.dataset.ch;
        player.channelState[ch].duty = parseInt(e.target.value, 10);
      });
    });

    document.querySelectorAll('.vol-inp').forEach(inp => {
      inp.addEventListener('input', (e) => {
        const ch = e.target.dataset.ch;
        player.channelState[ch].vol = parseInt(e.target.value, 10);
      });
    });

    // Mute chips
    ['p1', 'p2', 'tri', 'dmc'].forEach(id => {
      const chKey = { p1: 'pulse1', p2: 'pulse2', tri: 'triangle', dmc: 'dmc' }[id];
      const el = document.getElementById(`mute-${id}`);
      el.addEventListener('click', () => {
        const muted = !player.channelState[chKey].mute;
        player.channelState[chKey].mute = muted;
        el.classList.toggle('active', muted);
      });
    });

    // Pattern Select & Management
    patternSelect.addEventListener('change', (e) => {
      curPattern = e.target.value;
      curPatBadge.textContent = curPattern;
      renderGrid();
      if (curChannel === 'dmc') renderDrumView();
    });

    document.getElementById('btn-new-pattern').addEventListener('click', () => {
      const name = prompt('新しい小節パターン名 (例: B1, C1):', 'C1');
      if (name && !song.patterns[name]) {
        pushUndo();
        song.patterns[name] = {
          mel: new Array(16).fill(0),
          harm: new Array(16).fill(0),
          bass: new Array(16).fill(0),
          drums: new Array(16).fill(0)
        };
        curPattern = name;
        syncUI();
      }
    });

    document.getElementById('btn-dup-pattern').addEventListener('click', () => {
      const name = prompt('複製先の小節パターン名:', `${curPattern}_copy`);
      if (name && !song.patterns[name]) {
        pushUndo();
        song.patterns[name] = JSON.parse(JSON.stringify(song.patterns[curPattern]));
        curPattern = name;
        syncUI();
      }
    });

    document.getElementById('btn-rename-pattern').addEventListener('click', () => {
      const newName = prompt('新しい小節パターン名:', curPattern);
      if (newName && newName !== curPattern && !song.patterns[newName]) {
        pushUndo();
        song.patterns[newName] = song.patterns[curPattern];
        delete song.patterns[curPattern];
        song.order = song.order.map(k => (k === curPattern ? newName : k));
        curPattern = newName;
        syncUI();
      }
    });

    document.getElementById('btn-del-pattern').addEventListener('click', () => {
      const patKeys = Object.keys(song.patterns);
      if (patKeys.length <= 1) {
        alert('最低1つの小節パターンが必要です。');
        return;
      }
      if (confirm(`小節パターン "${curPattern}" を削除しますか？`)) {
        pushUndo();
        delete song.patterns[curPattern];
        song.order = song.order.filter(k => k !== curPattern);
        if (song.order.length === 0) song.order = [Object.keys(song.patterns)[0]];
        curPattern = song.order[0];
        syncUI();
      }
    });

    // JSON Save & Load
    document.getElementById('btn-save-json').addEventListener('click', () => {
      const jsonStr = player.exportJson(song);
      const blob = new Blob([jsonStr], { type: 'application/json' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `${(song.title || 'song').toLowerCase().replace(/[^a-z0-9]+/g, '_')}.nesbgm.json`;
      a.click();
      resetBaseline();
    });

    document.getElementById('btn-load-json').addEventListener('click', () => {
      document.getElementById('file-input-json').click();
    });

    document.getElementById('file-input-json').addEventListener('change', (e) => {
      const file = e.target.files[0];
      if (!file) return;
      const reader = new FileReader();
      reader.onload = (evt) => {
        try {
          const loaded = player.parseJson(evt.target.result);
          pushUndo();
          song = loaded;
          curOrderIdx = 0;
          curPattern = (song.order && song.order[0]) || Object.keys(song.patterns)[0];
          resetBaseline();
          alert(`楽曲 "${song.title || file.name}" を読み込みました！`);
        } catch (err) {
          alert('JSONの読み込みに失敗しました: ' + err);
        }
      };
      reader.readAsText(file);
    });

    // ASM Export Modal
    document.getElementById('btn-export-asm').addEventListener('click', () => {
      const asm = player.exportAsm(song, 'stg');
      document.getElementById('asm-export-text').value = asm;
      document.getElementById('modal-export-asm').classList.add('open');
    });

    document.getElementById('btn-copy-asm').addEventListener('click', () => {
      const txt = document.getElementById('asm-export-text');
      txt.select();
      navigator.clipboard.writeText(txt.value);
      alert('クリップボードにコピーしました！');
    });

    document.getElementById('btn-download-asm').addEventListener('click', () => {
      const asm = document.getElementById('asm-export-text').value;
      const blob = new Blob([asm], { type: 'text/plain' });
      const a = document.createElement('a');
      a.href = URL.createObjectURL(blob);
      a.download = `music_${(song.title || 'track').toLowerCase().replace(/[^a-z0-9]+/g, '_')}.s`;
      a.click();
      resetBaseline();
    });

    // ASM Import Modal
    document.getElementById('btn-import-asm').addEventListener('click', () => {
      document.getElementById('modal-import-asm').classList.add('open');
    });

    document.getElementById('btn-do-import-asm').addEventListener('click', () => {
      const asm = document.getElementById('asm-import-text').value;
      try {
        const loaded = player.parseAsm(asm);
        if (Object.keys(loaded.patterns).length === 0) {
          throw new Error('小節パターンが見つかりませんでした');
        }
        player.stop();
        pushUndo();
        song = loaded;
        curOrderIdx = 0;
        curPattern = song.order[0] || Object.keys(song.patterns)[0];
        resetBaseline();
        document.getElementById('modal-import-asm').classList.remove('open');
        alert('ASM データのインポートに成功しました！');
      } catch (err) {
        alert('インポート失敗: ' + err.message);
      }
    });

    // Modal close buttons
    document.querySelectorAll('.close-modal').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.modal').forEach(m => m.classList.remove('open'));
      });
    });
  }

  // Start initialization on DOM Ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
