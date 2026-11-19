// LibFlatyUI - makes Media/Holes/Rounded/R000-R100.tga from the masks.
// A hole file is the mask turned inside out, at half size in its middle:
// clear inside the shape, white around it up to the file's edges. Used as
// a second mask it cuts the shape's inside out of a texture (SetShapeRing).
//   node tools/make-holes.mjs      (from the library folder)

import { readFileSync, writeFileSync, mkdirSync, readdirSync } from "node:fs";
import { join } from "node:path";

const SRC = join("Media", "Masks", "Rounded");
const DST = join("Media", "Holes", "Rounded");

// 32-bit TGA (raw or RLE) -> { w, h, a: alpha per pixel, top row first }
function readTga(buf) {
    const idLen = buf[0], type = buf[2];
    const w = buf.readUInt16LE(12), h = buf.readUInt16LE(14);
    const bpp = buf[16], topFirst = (buf[17] & 0x20) !== 0;
    if (bpp !== 32 || (type !== 2 && type !== 10)) throw new Error("32-bit TGA expected");
    const px = Buffer.alloc(w * h * 4);
    let p = 18 + idLen, o = 0;
    if (type === 2) {
        buf.copy(px, 0, p, p + px.length);
    } else {
        while (o < px.length) {
            const head = buf[p++], count = (head & 0x7f) + 1;
            if (head & 0x80) {
                for (let i = 0; i < count; i++) { buf.copy(px, o, p, p + 4); o += 4; }
                p += 4;
            } else {
                buf.copy(px, o, p, p + count * 4); o += count * 4; p += count * 4;
            }
        }
    }
    const a = new Uint8Array(w * h);
    for (let y = 0; y < h; y++) {
        const row = topFirst ? y : h - 1 - y;
        for (let x = 0; x < w; x++) a[y * w + x] = px[(row * w + x) * 4 + 3];
    }
    return { w, h, a };
}

// white RLE TGA from alpha per pixel (top row first)
function writeTga(w, h, a) {
    const out = [Buffer.from([0, 0, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, w & 255, w >> 8, h & 255, h >> 8, 32, 0x28])];
    for (let y = 0; y < h; y++) {
        let x = 0;
        while (x < w) {
            let n = 1;
            const v = a[y * w + x];
            while (x + n < w && n < 128 && a[y * w + x + n] === v) n++;
            out.push(Buffer.from([0x80 | (n - 1), 255, 255, 255, v]));
            x += n;
        }
    }
    return Buffer.concat(out);
}

mkdirSync(DST, { recursive: true });
for (const file of readdirSync(SRC).filter((f) => /^R\d{3}\.tga$/.test(f))) {
    const m = readTga(readFileSync(join(SRC, file)));
    const half = m.w / 2, off = half / 2;
    const a = new Uint8Array(m.w * m.h).fill(255);
    for (let y = 0; y < half; y++) {
        for (let x = 0; x < half; x++) {
            // the mask's 2 x 2 pixels, turned inside out
            const i = 2 * y * m.w + 2 * x;
            const v = (m.a[i] + m.a[i + 1] + m.a[i + m.w] + m.a[i + m.w + 1]) / 4;
            a[(y + off) * m.w + x + off] = 255 - Math.round(v);
        }
    }
    writeFileSync(join(DST, file), writeTga(m.w, m.h, a));
}
console.log("holes written to " + DST);
