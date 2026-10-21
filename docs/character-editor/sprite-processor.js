/**
 * MOJAxMOJA WARS - Sprite & Palette Processor Module
 * NES 2A03/2C02 PPU compliant image processor, palette quantizer, and 8x8 tile deduplicator.
 */

(function(window) {
  'use strict';

  // NES Master Palette (54 standard colors in sRGB hex)
  const NES_MASTER_PALETTE = [
  // $00 - $0F
  { id: 0x00, hex: "#666666", r: 102, g: 102, b: 102, name: "Gray" },
  { id: 0x01, hex: "#002A88", r:   0, g:  42, b: 136, name: "Deep Blue" },
  { id: 0x02, hex: "#1412A7", r:  20, g:  18, b: 167, name: "Dark Violet" },
  { id: 0x03, hex: "#3B00A4", r:  59, g:   0, b: 164, name: "Purple" },
  { id: 0x04, hex: "#5C007E", r:  92, g:   0, b: 126, name: "Magenta" },
  { id: 0x05, hex: "#6E0040", r: 110, g:   0, b:  64, name: "Crimson" },
  { id: 0x06, hex: "#6C0600", r: 108, g:   6, b:   0, name: "Dark Red" },
  { id: 0x07, hex: "#561D00", r:  86, g:  29, b:   0, name: "Brown" },
  { id: 0x08, hex: "#333500", r:  51, g:  53, b:   0, name: "Olive" },
  { id: 0x09, hex: "#0B4800", r:  11, g:  72, b:   0, name: "Dark Green" },
  { id: 0x0A, hex: "#005200", r:   0, g:  82, b:   0, name: "Green" },
  { id: 0x0B, hex: "#004F08", r:   0, g:  79, b:   8, name: "Forest Green" },
  { id: 0x0C, hex: "#00404D", r:   0, g:  64, b:  77, name: "Dark Teal" },
  { id: 0x0D, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },
  { id: 0x0E, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },
  { id: 0x0F, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },

  // $10 - $1F
  { id: 0x10, hex: "#ADADAD", r: 173, g: 173, b: 173, name: "Light Gray" },
  { id: 0x11, hex: "#155FD9", r:  21, g:  95, b: 217, name: "Blue" },
  { id: 0x12, hex: "#4240FF", r:  66, g:  64, b: 255, name: "Violet" },
  { id: 0x13, hex: "#7527FE", r: 117, g:  39, b: 254, name: "Royal Purple" },
  { id: 0x14, hex: "#A01ACC", r: 160, g:  26, b: 204, name: "Orchid" },
  { id: 0x15, hex: "#B71E7B", r: 183, g:  30, b: 123, name: "Rose" },
  { id: 0x16, hex: "#B53120", r: 181, g:  49, b:  32, name: "Red" },
  { id: 0x17, hex: "#994E00", r: 153, g:  78, b:   0, name: "Orange Brown" },
  { id: 0x18, hex: "#6B6D00", r: 107, g: 109, b:   0, name: "Ochre" },
  { id: 0x19, hex: "#388700", r:  56, g: 135, b:   0, name: "Lime" },
  { id: 0x1A, hex: "#0C9300", r:  12, g: 147, b:   0, name: "Bright Green" },
  { id: 0x1B, hex: "#008F32", r:   0, g: 143, b:  50, name: "Emerald" },
  { id: 0x1C, hex: "#007C8D", r:   0, g: 124, b: 141, name: "Teal" },
  { id: 0x1D, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },
  { id: 0x1E, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },
  { id: 0x1F, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },

  // $20 - $2F
  { id: 0x20, hex: "#FFFFFF", r: 255, g: 255, b: 255, name: "White" },
  { id: 0x21, hex: "#64B0FF", r: 100, g: 176, b: 255, name: "Sky Blue" },
  { id: 0x22, hex: "#9290FF", r: 146, g: 144, b: 255, name: "Lavender" },
  { id: 0x23, hex: "#C676FF", r: 198, g: 118, b: 255, name: "Lilac" },
  { id: 0x24, hex: "#F36AFF", r: 243, g: 106, b: 255, name: "Pink" },
  { id: 0x25, hex: "#FE6ECC", r: 254, g: 110, b: 204, name: "Coral Pink" },
  { id: 0x26, hex: "#FE8176", r: 254, g: 129, b: 118, name: "Salmon" },
  { id: 0x27, hex: "#ECA02B", r: 236, g: 160, b:  43, name: "Gold / Orange" },
  { id: 0x28, hex: "#BACB00", r: 186, g: 203, b:   0, name: "Yellow Green" },
  { id: 0x29, hex: "#87E200", r: 135, g: 226, b:   0, name: "Spring Green" },
  { id: 0x2A, hex: "#55EE38", r:  85, g: 238, b:  56, name: "Mint" },
  { id: 0x2B, hex: "#46EB8B", r:  70, g: 235, b: 139, name: "Sea Green" },
  { id: 0x2C, hex: "#48DCE9", r:  72, g: 220, b: 233, name: "Cyan" },
  { id: 0x2D, hex: "#4F4F4F", r:  79, g:  79, b:  79, name: "Medium Gray" },
  { id: 0x2E, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },
  { id: 0x2F, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },

  // $30 - $3F
  { id: 0x30, hex: "#FFFFFF", r: 255, g: 255, b: 255, name: "Pure White" },
  { id: 0x31, hex: "#C0E0FF", r: 192, g: 224, b: 255, name: "Pale Blue" },
  { id: 0x32, hex: "#D3D2FF", r: 211, g: 210, b: 255, name: "Pale Lavender" },
  { id: 0x33, hex: "#E8C8FF", r: 232, g: 200, b: 255, name: "Pale Lilac" },
  { id: 0x34, hex: "#FBC2FF", r: 251, g: 194, b: 255, name: "Pale Pink" },
  { id: 0x35, hex: "#FEC4EA", r: 254, g: 196, b: 234, name: "Pale Coral" },
  { id: 0x36, hex: "#FECCC5", r: 254, g: 204, b: 197, name: "Pale Salmon" },
  { id: 0x37, hex: "#F7D8A5", r: 247, g: 216, b: 165, name: "Warm Cream" },
  { id: 0x38, hex: "#E4E594", r: 228, g: 229, b: 148, name: "Pale Yellow" },
  { id: 0x39, hex: "#CFEF96", r: 207, g: 239, b: 150, name: "Pale Lime" },
  { id: 0x3A, hex: "#BDF4AB", r: 189, g: 244, b: 171, name: "Pale Mint" },
  { id: 0x3B, hex: "#B3F3CE", r: 179, g: 243, b: 206, name: "Pale Cyan" },
  { id: 0x3C, hex: "#B2ECF4", r: 178, g: 236, b: 244, name: "Ice Blue" },
  { id: 0x3D, hex: "#B8B8B8", r: 184, g: 184, b: 184, name: "Light Gray" },
  { id: 0x3E, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },
  { id: 0x3F, hex: "#000000", r:   0, g:   0, b:   0, name: "Black" },
];

/**
 * Calculates color distance (weighted Euclidean distance).
 */
function colorDistance(r1, g1, b1, r2, g2, b2) {
  const rmean = (r1 + r2) / 2;
  const dr = r1 - r2;
  const dg = g1 - g2;
  const db = b1 - b2;
  return Math.sqrt((((512 + rmean) * dr * dr) >> 8) + 4 * dg * dg + (((767 - rmean) * db * db) >> 8));
}

/**
 * Finds closest NES Master Palette entry.
 */
function findClosestNesColor(r, g, b) {
  let minD = Infinity;
  let best = NES_MASTER_PALETTE[0];
  for (const c of NES_MASTER_PALETTE) {
    const d = colorDistance(r, g, b, c.r, c.g, c.b);
    if (d < minD) {
      minD = d;
      best = c;
    }
  }
  return best;
}

/**
 * Detects if the image has a solid background (e.g. solid black in JPEGs) from corners and edges.
 * Returns { r, g, b } or null if alpha transparency is already used.
 */
function detectSolidBackgroundColor(data, width, height) {
  // Check if image already has significant transparent pixels
  let transparentCount = 0;
  for (let i = 3; i < data.length; i += 16) {
    if (data[i] < 64) transparentCount++;
  }
  if (transparentCount > (data.length / 16) * 0.05) {
    return null; // Image already uses alpha transparency
  }

  // Sample the 4 corners and borders
  const samplePoints = [
    [0, 0], [width - 1, 0], [0, height - 1], [width - 1, height - 1],
    [Math.floor(width / 2), 0], [0, Math.floor(height / 2)],
    [width - 1, Math.floor(height / 2)], [Math.floor(width / 2), height - 1]
  ];

  const cornerColors = samplePoints.map(([x, y]) => {
    const idx = (y * width + x) * 4;
    return { r: data[idx], g: data[idx + 1], b: data[idx + 2] };
  });

  // Check if corners are mostly black/near-black (RGB all < 40)
  const isDark = cornerColors.every(c => c.r < 45 && c.g < 45 && c.b < 45);
  if (isDark) {
    return { r: 0, g: 0, b: 0, tolerance: 45 };
  }

  // Check if all corners match each other within tolerance
  const c0 = cornerColors[0];
  const allMatch = cornerColors.every(c => colorDistance(c0.r, c0.g, c0.b, c.r, c.g, c.b) < 30);
  if (allMatch) {
    return { r: c0.r, g: c0.g, b: c0.b, tolerance: 35 };
  }

  return null;
}

/**
 * Automatically detects the pixel-art grid size for large / upscaled images (e.g. 512x512, 1024x1024).
 * Common target NES sprite sizes: 16x16, 24x24, 32x32, 48x48.
 */
function autoDownscalePixelArt(sourceCanvas, img) {
  const srcW = img.width;
  const srcH = img.height;

  // If already pixel size, return directly
  if (srcW <= 48 && srcH <= 48) {
    const ctx = sourceCanvas.getContext('2d');
    const imgData = ctx.getImageData(0, 0, srcW, srcH);
    const solidBg = detectSolidBackgroundColor(imgData.data, srcW, srcH);
    return {
      width: srcW,
      height: srcH,
      imgData,
      solidBg,
      wasDownscaled: false,
      factor: 1
    };
  }

  // Test candidate grid dimensions
  const candidates = [32, 24, 16, 48];
  let bestCandidate = 32;
  let minDiff = Infinity;

  for (const cand of candidates) {
    const step = srcW / cand;
    const diff = Math.abs(step - Math.round(step));
    if (diff < minDiff) {
      minDiff = diff;
      bestCandidate = cand;
    }
  }

  const targetW = bestCandidate;
  const targetH = Math.round(srcH * (bestCandidate / srcW));
  const stepX = srcW / targetW;
  const stepY = srcH / targetH;

  const srcCtx = sourceCanvas.getContext('2d');
  const srcData = srcCtx.getImageData(0, 0, srcW, srcH);
  const solidBg = detectSolidBackgroundColor(srcData.data, srcW, srcH);

  // Create downscaled ImageData using center-pixel sampling
  const outCanvas = document.createElement('canvas');
  outCanvas.width = targetW;
  outCanvas.height = targetH;
  const outCtx = outCanvas.getContext('2d');
  const outData = outCtx.createImageData(targetW, targetH);

  for (let y = 0; y < targetH; y++) {
    for (let x = 0; x < targetW; x++) {
      const srcPx = Math.floor(x * stepX + stepX * 0.5);
      const srcPy = Math.floor(y * stepY + stepY * 0.5);
      const srcIdx = (srcPy * srcW + srcPx) * 4;
      const outIdx = (y * targetW + x) * 4;

      let r = srcData.data[srcIdx];
      let g = srcData.data[srcIdx + 1];
      let b = srcData.data[srcIdx + 2];
      let a = srcData.data[srcIdx + 3];

      // If solid background detected, mark as transparent
      if (solidBg) {
        const d = colorDistance(r, g, b, solidBg.r, solidBg.g, solidBg.b);
        if (d < solidBg.tolerance) {
          a = 0; // Transparent
        }
      }

      outData.data[outIdx] = r;
      outData.data[outIdx + 1] = g;
      outData.data[outIdx + 2] = b;
      outData.data[outIdx + 3] = a;
    }
  }

  return {
    width: targetW,
    height: targetH,
    imgData: outData,
    solidBg,
    wasDownscaled: true,
    factor: Math.round(srcW / targetW)
  };
}

/**
 * Quantize an ImageData to the best 3 colors from the NES master palette + 1 transparent color.
 * Returns { subpalette: [null, c1, c2, c3], indexedPixels: Uint8Array(width * height) }
 */
function quantizeImageToNesSubpalette(imageData, alphaThreshold = 64, solidBg = null) {
  const { width, height, data } = imageData;
  const colorMap = new Map();

  for (let i = 0; i < data.length; i += 4) {
    const a = data[i + 3];
    if (a < alphaThreshold) continue;

    const r = data[i];
    const g = data[i + 1];
    const b = data[i + 2];

    if (solidBg) {
      const d = colorDistance(r, g, b, solidBg.r, solidBg.g, solidBg.b);
      if (d < solidBg.tolerance) continue; // Skip solid background color
    }

    const nesCol = findClosestNesColor(r, g, b);
    const key = nesCol.id;

    if (!colorMap.has(key)) {
      colorMap.set(key, { nesCol, count: 0 });
    }
    colorMap.get(key).count++;
  }

  const sorted = Array.from(colorMap.values()).sort((a, b) => b.count - a.count);

  const defaultColors = [
    NES_MASTER_PALETTE.find(c => c.id === 0x0f) || NES_MASTER_PALETTE[13],
    NES_MASTER_PALETTE.find(c => c.id === 0x16) || NES_MASTER_PALETTE[22],
    NES_MASTER_PALETTE.find(c => c.id === 0x20) || NES_MASTER_PALETTE[32],
  ];

  const subpalette = [null];
  for (let c = 0; c < 3; c++) {
    if (sorted[c]) {
      subpalette.push(sorted[c].nesCol);
    } else {
      subpalette.push(defaultColors[c]);
    }
  }

  const indexedPixels = new Uint8Array(width * height);
  for (let i = 0; i < width * height; i++) {
    const p = i * 4;
    const a = data[p + 3];
    if (a < alphaThreshold) {
      indexedPixels[i] = 0;
      continue;
    }

    const r = data[p];
    const g = data[p + 1];
    const b = data[p + 2];

    if (solidBg) {
      const d = colorDistance(r, g, b, solidBg.r, solidBg.g, solidBg.b);
      if (d < solidBg.tolerance) {
        indexedPixels[i] = 0;
        continue;
      }
    }

    let bestIdx = 1;
    let minD = Infinity;
    for (let c = 1; c <= 3; c++) {
      const col = subpalette[c];
      const d = colorDistance(r, g, b, col.r, col.g, col.b);
      if (d < minD) {
        minD = d;
        bestIdx = c;
      }
    }
    indexedPixels[i] = bestIdx;
  }

  return { subpalette, indexedPixels };
}

/**
 * Slices indexedPixels (width x height) into an array of 8x8 tiles with relative positions.
 */
function decomposeIntoMetaSprites(width, height, indexedPixels) {
  const tilesX = Math.ceil(width / 8);
  const tilesY = Math.ceil(height / 8);

  const uniqueTileSignatures = new Map();
  const deduplicatedTiles = [];
  const spriteInstances = [];

  for (let ty = 0; ty < tilesY; ty++) {
    for (let tx = 0; tx < tilesX; tx++) {
      const tileData = new Uint8Array(64);
      let hasVisiblePixel = false;

      for (let py = 0; py < 8; py++) {
        for (let px = 0; px < 8; px++) {
          const srcX = tx * 8 + px;
          const srcY = ty * 8 + py;
          let val = 0;
          if (srcX < width && srcY < height) {
            val = indexedPixels[srcY * width + srcX];
          }
          tileData[py * 8 + px] = val;
          if (val > 0) hasVisiblePixel = true;
        }
      }

      if (!hasVisiblePixel) continue;

      const sig = Array.from(tileData).join(',');
      let tileIndex;
      if (uniqueTileSignatures.has(sig)) {
        tileIndex = uniqueTileSignatures.get(sig);
      } else {
        tileIndex = deduplicatedTiles.length;
        uniqueTileSignatures.set(sig, tileIndex);
        deduplicatedTiles.push(tileData);
      }

      spriteInstances.push({
        relX: tx * 8,
        relY: ty * 8,
        tileIndex,
        attr: 0,
      });
    }
  }

  return {
    spriteInstances,
    deduplicatedTiles,
    tilesX,
    tilesY,
  };
}

/**
 * Scanline Sprite Counter:
 */
function analyzeScanlineDensity(spriteInstances, height) {
  const lineCounts = new Uint8Array(height || 128);
  let maxCount = 0;
  const overloadedLines = [];

  for (const sp of spriteInstances) {
    const yStart = sp.relY;
    const yEnd = yStart + 8;
    for (let y = yStart; y < yEnd && y < lineCounts.length; y++) {
      lineCounts[y]++;
      if (lineCounts[y] > maxCount) {
        maxCount = lineCounts[y];
      }
    }
  }

  for (let y = 0; y < lineCounts.length; y++) {
    if (lineCounts[y] > 8) {
      overloadedLines.push({ y, count: lineCounts[y] });
    }
  }

  return {
    lineCounts,
    maxCount,
    isOverLimit: maxCount > 8,
    overloadedLines,
  };
}

/**
 * Encodes an 8x8 indexed tile (64 bytes, values 0..3) into NES 2bpp CHR format (16 bytes).
 */
function tile8x8ToNesChr(tile64) {
  const chr16 = new Uint8Array(16);
  for (let y = 0; y < 8; y++) {
    let p0 = 0;
    let p1 = 0;
    for (let x = 0; x < 8; x++) {
      const val = tile64[y * 8 + x] & 0x03;
      p0 = (p0 << 1) | (val & 1);
      p1 = (p1 << 1) | ((val >> 1) & 1);
    }
    chr16[y] = p0;
    chr16[y + 8] = p1;
  }
  return chr16;
}

/**
 * Formats CHR tiles as ca65 assembly (.byte $xx, $yy...)
 */
function formatChrAsAssembly(tiles64List, labelPrefix = "char_tiles") {
  const lines = [];
  lines.push(`; -----------------------------------------------------------------------------`);
  lines.push(`; CHR-ROM 2bpp Tile Data (${tiles64List.length} tiles / ${tiles64List.length * 16} bytes)`);
  lines.push(`; -----------------------------------------------------------------------------`);
  lines.push(`.segment "CHR"`);
  lines.push(`${labelPrefix}:`);

  tiles64List.forEach((tile64, idx) => {
    const chr16 = tile8x8ToNesChr(tile64);
    const hexPlane0 = Array.from(chr16.slice(0, 8)).map(b => `$${b.toString(16).padStart(2, '0')}`).join(', ');
    const hexPlane1 = Array.from(chr16.slice(8, 16)).map(b => `$${b.toString(16).padStart(2, '0')}`).join(', ');
    lines.push(`  ; Tile ${idx} (Offset +$${(idx * 16).toString(16).padStart(4, '0')})`);
    lines.push(`  .byte ${hexPlane0}  ; Plane 0`);
    lines.push(`  .byte ${hexPlane1}  ; Plane 1`);
  });

  return lines.join('\n');
}

// Attach to window for seamless offline file:/// execution
window.SpriteProcessor = {
  NES_MASTER_PALETTE,
  colorDistance,
  findClosestNesColor,
  quantizeImageToNesSubpalette,
  decomposeIntoMetaSprites,
  analyzeScanlineDensity,
  tile8x8ToNesChr,
  formatChrAsAssembly,
  autoDownscalePixelArt
};

})(window);

